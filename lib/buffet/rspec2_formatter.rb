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

        def example_to_hash(example)
          example.description
        end
        
        def example_passed(example)
          super
          @@buffet_server.example_passed({:description => example.description})
        end

        def example_failed(example)
          super(example)
          exception = example.metadata[:execution_result][:exception]
          message = exception.message 
          backtrace = format_backtrace(exception.backtrace, example).join("\n")
          description = example.description || "No description!"

          failure = {:header    => description,
                     :backtrace => "No backtrace yet.", #TODO.
                     :message   => message, 
                     :location  => backtrace}

          @@buffet_server.example_failed({:a => "ff"}, failure)
        end

        def example_pending(example, message, deprecated_pending_location=nil)
          super
          @@buffet_server.example_pending(example_to_hash example)
        end
      end
    end
  end
end
