# frozen_string_literal: true
require 'zlib'
require 'base64'

require 'raven/version'
require 'raven/okjson'
require 'raven/transports/http'

module Raven
  # Encodes events and sends them to the Sentry server.
  class Client
    PROTOCOL_VERSION = '5'.freeze
    USER_AGENT = "raven-ruby/#{Raven::VERSION}".freeze
    CONTENT_TYPE = 'application/json'.freeze

    attr_accessor :configuration

    def initialize(configuration)
      @configuration = configuration
      @processors = configuration.processors.map { |v| v.new(self) }
      @state = ClientState.new
    end

    def send_event(event)
      return false unless configuration_allows_sending

      # Convert to hash
      event = event.to_hash

      unless @state.should_try?
        failed_send(nil, event)
        return
      end

      Raven.logger.debug "Sending event #{event[:event_id]} to Sentry"

      content_type, encoded_data = encode(event)

      begin
        transport.send_event(generate_auth_header, encoded_data,
                       :content_type => content_type)
        successful_send
      rescue => e
        failed_send(e, event)
        return
      end

      event
    end

    def transport
      @transport ||=
        case configuration.scheme
        when 'http', 'https'
          Transports::HTTP.new(configuration)
        when 'dummy'
          Transports::Dummy.new(configuration)
        else
          fail "Unknown transport scheme '#{configuration.scheme}'"
        end
    end

    private

    def configuration_allows_sending
      if configuration.send_in_current_environment?
        true
      else
        configuration.log_excluded_environment_message
        false
      end
    end

    def encode(event)
      hash = @processors.reduce(event.to_hash) { |memo, p| p.process(memo) }
      encoded = OkJson.encode(hash)

      case configuration.encoding
      when 'gzip'
        ['application/octet-stream', Base64.strict_encode64(Zlib::Deflate.deflate(encoded))]
      else
        ['application/json', encoded]
      end
    end

    def get_log_message(event)
      (event && event[:message]) || '<no message value>'
    end

    def generate_auth_header
      now = Time.now.to_i.to_s
      fields = {
        'sentry_version' => PROTOCOL_VERSION,
        'sentry_client' => USER_AGENT,
        'sentry_timestamp' => now,
        'sentry_key' => configuration.public_key,
        'sentry_secret' => configuration.secret_key
      }
      'Sentry ' + fields.map { |key, value| "#{key}=#{value}" }.join(', ')
    end

    def successful_send
      @state.success
    end

    def failed_send(e, event)
      @state.failure
      if e # exception was raised
        Raven.logger.error "Unable to record event with remote Sentry server (#{e.class} - #{e.message})"
        e.backtrace[0..10].each { |line| Raven.logger.error(line) }
      else
        Raven.logger.error "Not sending event due to previous failure(s)."
      end
      Raven.logger.error("Failed to submit event: #{get_log_message(event)}")
      configuration.transport_failure_callback.call(event) if configuration.transport_failure_callback
    end
  end

  class ClientState
    def initialize
      reset
    end

    def should_try?
      return true if @status == :online

      interval = @retry_after || [@retry_number, 6].min ** 2
      return true if Time.now - @last_check >= interval

      false
    end

    def failure(retry_after = nil)
      @status = :error
      @retry_number += 1
      @last_check = Time.now
      @retry_after = retry_after
    end

    def success
      reset
    end

    def reset
      @status = :online
      @retry_number = 0
      @last_check = nil
      @retry_after = nil
    end

    def failed?
      @status == :error
    end
  end
end
