require 'logger'

module Raven
  module BreadcrumbLogger
    LEVELS = {
      ::Logger::DEBUG => 'debug',
      ::Logger::INFO  => 'info',
      ::Logger::WARN  => 'warn',
      ::Logger::ERROR => 'error',
      ::Logger::FATAL => 'fatal'
    }.freeze

    EXC_FORMAT = /^([a-zA-Z0-9]+)\:\s(.*)$/

    def self.parse_exception(message)
      lines = message.split(/\n\s*/)
      return nil unless lines.length > 2

      match = lines[0].match(EXC_FORMAT)
      return nil unless match

      _, type, value = match.to_a
      [type, value]
    end

    def add(severity, message = nil, progname = nil, &block)
      # This is pulled in from Logger:add, and is needed due to the
      # way logger's internal syntax works
      severity ||= UNKNOWN
      progname ||= self.progname
      if message.nil?
        if block_given?
          message = yield
        else
          message = progname
          progname = self.progname
        end
      end

      super

      return if progname == "sentry" || Raven.configuration.exclude_loggers.include?(progname)

      return if message.nil? || message == ""

      # some loggers will add leading/trailing space as they (incorrectly, mind you)
      # think of logging as a shortcut to std{out,err}
      message = message.strip

      last_crumb = Raven.breadcrumbs.peek
      # try to avoid dupes from logger broadcasts
      if last_crumb.nil? || last_crumb.message != message
        error = Raven::BreadcrumbLogger.parse_exception(message)
        # TODO(dcramer): we need to filter out the "currently captured error"
        if error
          Raven.breadcrumbs.record do |crumb|
            crumb.level = Raven::BreadcrumbLogger::LEVELS.fetch(severity, nil)
            crumb.category = progname || 'error'
            crumb.type = 'error'
            crumb.data = {
              :type => error[0],
              :value => error[1]
            }
          end
        else
          Raven.breadcrumbs.record do |crumb|
            crumb.level = Raven::BreadcrumbLogger::LEVELS.fetch(severity, nil)
            crumb.message = message
            crumb.category = progname || 'logger'
          end
        end
      end
    end
  end
end

class Logger
  prepend Raven::BreadcrumbLogger
end
