require 'spec/runner/formatter/base_text_formatter'

module Spec
  module Runner
    module Formatter
      class AugmentedTextFormatter < BaseTextFormatter
        def self.configure buffet_server, slave_name
          @@buffet_server = buffet_server
          @@slave_name = slave_name
        end

        def example_passed example_proxy
          super
          @@buffet_server.example_passed(@@slave_name, {
            :description => example_proxy.description,
            :location    => example_proxy.location,
            :slave_name  => @@slave_name,
          })
        end

        def example_failed example_proxy, counter, failure
          super
          @@buffet_server.example_failed(@@slave_name, {
            :backtrace   => failure.exception.backtrace.join("\n"),
            :description => failure.header,
            :location    => example_proxy.location,
            :message     => failure.exception.message,
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
