require 'drb'
require 'thread'
require 'socket'

module Buffet
  class Master
    attr_reader :failures, :passes, :stats

    def initialize project, slaves, specs
      @project = project
      @slaves = slaves
      @stats = {:examples => 0, :failures => 0, :pending => 0}
      @lock = Mutex.new
      @failures = []
      @passes = []
      @specs = specs.shuffle # Never have the same test distribution
    end

    def run
      start_service
      @stats[:start_time] = Time.now

      threads = @slaves.map do |slave|
        Thread.new do
          slave.execute_in_project ".buffet/buffet-worker #{server_uri} #{Settings.framework}"
        end
      end

      threads.each { |t| t.join }

      @stats[:end_time] = Time.now
      @stats[:total_time] = @stats[:end_time] - @stats[:start_time]
      stop_service
    end

    def next_file
      @lock.synchronize do
        file = @specs.shift
        Buffet.logger.info "Dequeued #{file}"
        file
      end
    end

    def example_passed(details)
      @lock.synchronize do
        @stats[:examples] += 1
      end

      @passes.push({:description => details[:description]})
    end

    def example_failed(details)
      @lock.synchronize do
        @stats[:examples] += 1
        @stats[:failures] += 1

        @failures.push(details)
      end
    end

    def example_pending(details)
     @lock.synchronize do
       @stats[:examples] += 1
       @stats[:pending] += 1
     end
    end

    private

    def server_uri
      @drb_server.uri
    end

    def start_service
      @drb_server = DRb.start_service("druby://#{ip}:0", self)
    end

    def stop_service
      DRb.stop_service
    end

    def ip
      result = Buffet.run! 'host `hostname -s`'
      result.stdout.chomp.match(/((\d+\.){3}\d+)/)[1]
    end
  end
end
