#!/usr/bin/env ruby

require 'drb'
require 'thread'
require 'socket'
require 'memoize'

module Buffet
  # The Buffet::Master class runs worker on all of the host machines 
  # (including itself), and then distributes the tests to the workers.
  # The workers request more tests after they finish their current tests.
  class Master 
    extend Memoize

    # This will initialize the server.
    def initialize(working_dir, hosts, status) 
      @ip = Socket.gethostname.split('.').first # For druby
      @port = 8990 # For druby
      @hosts = hosts # All host machines
      @stats = {:examples => 0, :failures => 0} # Failures and total test #.
      @lock = Mutex.new # Lock objects touched by several threads to avoid race.
      @failure_list = [] # Details of the failure we have.
      @working_dir = working_dir # Directory we clone and run tests in.
      @status = status #RFCTR: Use status

      Dir.chdir(@working_dir) do
        @files = Dir["spec/**/*_spec.rb"].sort #This is specific to rspec.
      end
    end

    def next_file
      @lock.synchronize do
        @files_to_run.shift
      end
    end

    # These two methods are called on passes and fails, respectively.

    def example_passed(location)
      @lock.synchronize do
        @stats[:examples] += 1
        update_status
      end
    end

    #TODO: Kwargs?
    def example_failed(location, header, backtrace)
      @lock.synchronize do
        @stats[:examples] += 1
        @stats[:failures] += 1

        backtrace ||= "No backtrace found."

        @failure_list.push({:location => location, :header => header, :backtrace => backtrace.to_s})
        update_status
      end
    end

    def update_status
      @status.set @stats
    end

    def server_addr
      "druby://#{@ip}:#{@port}"
    end

    def start_service
      @drb_thread = Thread.new do
        DRb.start_service("druby://0.0.0.0:#{@port}", self)
        DRb.thread.join
      end
    end

    def stop_service
      DRb.stop_service
      @drb_thread.join
    end

    # This will start distributing specs. It blocks until the tests are complete.
    def run
      update_status

      Dir.chdir(@working_dir) do
        @files_to_run = @files.dup

        start_service
        @start_time = Time.now

        # Run worker on every host.
        threads = @hosts.map do |host|
          Thread.new do
            #TODO: Maybe eventually pull these dirs out of settings.yml
            `ssh buffet@#{host} 'cd ~/#{Settings.root_dir_name}/working-directory; RAILS_ENV=test bundle exec ruby ~/#{Settings.root_dir_name}/bin/buffet_worker #{server_addr}'`

            if $?.exitstatus != 0
              puts "Error on worker machine #{host}."
            end
          end
        end

        threads.each do |t|
          t.join
        end

        @end_time = Time.now
        stop_service
      end

      results = ""
      @stats.each do |key, value|
        results += "#{key.capitalize}: #{value}\n"
      end

      results += "\n"
      mins, secs = (@end_time - @start_time).divmod(60)
      results += "Buffet was consumed in %d mins %d secs\n" % [mins, secs]

      @status.set results
    end

    def failures
      @failure_list
    end
  end
end
