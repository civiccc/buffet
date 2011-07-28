require 'spec/runner/formatter/base_text_formatter'

module Spec
  module Runner
    module Formatter
      class AugmentedTextFormatter < BaseTextFormatter
        def self.buffet_server=(buffet_server)
          @@buffet_server = buffet_server
        end

        def example_passed(example_proxy)
          super
          @@buffet_server.example_passed(example_proxy.location)
        end

        def example_failed(example_proxy, counter, failure)
          super
          @@buffet_server.example_failed(
            {:location  => example_proxy.location,
             :header    => failure.header,
             :message   => failure.exception.message,
             :backtrace => failure.exception.backtrace.join("\n")})
        end

        def example_pending(example, message, deprecated_pending_location=nil)
          super
          @@buffet_server.example_pending(example.location)
        end
      end
    end
  end
end
