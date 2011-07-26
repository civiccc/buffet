require 'rspec/core/formatters/base_text_formatter'

module RSpec
  module Core
    module Formatters
      class AugmentedTextFormatter < BaseTextFormatter
        def initialize(output)
          super(output)
        end

        def self.buffet_server=(buffet_server)
          @@buffet_server = buffet_server
        end
        
        def example_passed(example_proxy)
          super
          @@buffet_server.example_passed(example_proxy.location)
        end

        def example_failed(example_proxy)
          super
          @@buffet_server.example_failed( example_proxy.inspect , nil , nil)
        end

        def example_pending(example, message, deprecated_pending_location=nil)
          super
          @@buffet_server.example_pending(example.location)
        end
      end
    end
  end
end
