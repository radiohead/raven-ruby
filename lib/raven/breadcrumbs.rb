module Raven
  class Breadcrumb
    attr_accessor :category, :data, :message, :level, :timestamp, :type

    def initialize
      @category = nil
      @data = {}
      @level = nil
      @message = nil
      @timestamp = Time.now.to_i
      @type = nil
    end

    def to_hash
      {
        :category => @category,
        :data => @data,
        :level => @level,
        :message => @message,
        :timestamp => @timestamp,
        :type => @type
      }
    end
  end
end

module Raven
  class BreadcrumbBuffer
    def self.current
      Thread.current[:sentry_breadcrumbs] ||= new
    end

    def self.clear!
      Thread.current[:sentry_breadcrumbs] = nil
    end

    def initialize(size = 100)
      @count = 0
      @pos = 0
      @size = size
      @buffer = Array.new(size)
    end

    def record(crumb = nil)
      if block_given?
        crumb = Breadcrumb.new if crumb.nil?
        yield(crumb)
      end
      @buffer[@pos] = crumb
      @pos = (@pos + 1) % @size
      @count += 1
    end

    def peek
      @buffer[@pos - 1]
    end

    def each
      results = []
      (0..(@size - 1)).each do |i|
        node = @buffer[(@pos + i) % @size]
        results.push(node) unless node.nil?
      end
      results
    end

    def empty?
      @count == 0
    end

    def to_hash
      {
        :values => each.map(&:to_hash)
      }
    end
  end
end
