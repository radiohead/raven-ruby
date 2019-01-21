module Raven
  class Processor
    def initialize(client)
      @client = client
    end

    def process(_data)
      raise NotImplementedError
    end
  end
end
