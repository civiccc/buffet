require 'rspec/core/formatters/base_text_formatter'

module RSpec
  module Core
    module Formatters
      class AugmentedTextFormatter < BaseTextFormatter
        def initialize(output)
          super(output)
        end

        def self.configure buffet_server, slave_name
          @@buffet_server = buffet_server
          @@slave_name = slave_name
        end

        def example_passed example
          super
          @@buffet_server.example_passed(@@slave_name, {
            :description => example.description,
            :location    => example.location,
            :slave_name  => @@slave_name,
          })
        end

        def example_failed example
          super
          exception = example.metadata[:execution_result][:exception]
          backtrace = format_backtrace(exception.backtrace, example).join("\n")

          @@buffet_server.example_failed(@@slave_name, {
            :description => example.description,
            :backtrace   => backtrace,
            :message     => exception.message,
            :location    => example.location,
            :slave_name  => @@slave_name,
          })
        end

        def example_pending example, message, deprecated_pending_location=nil
          super
          @@buffet_server.example_pending(@@slave_name, {
            :description => example.description,
            :location    => example.location,
            :message     => message,
            :slave_name  => @@slave_name,
          })
        end
      end
    end
  end
end
