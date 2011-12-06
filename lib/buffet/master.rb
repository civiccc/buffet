#!/usr/bin/env ruby

require 'drb'
require 'thread'
require 'socket'

module Buffet
  class Master
    def initialize project, slaves
      @project = project
      @slaves = slaves
      @stats = {:examples => 0, :failures => 0}
      @lock = Mutex.new
      @failure_list = []
      @pass_list = []

      Dir.chdir(@project.directory) do
        @files = Dir['spec/**/*_spec.rb'].sort
      end
    end

    def run
      Dir.chdir(@project.directory) do
        @files_to_run = @files.dup

        start_service
        @start_time = Time.now

        threads = @slaves.map do |slave|
          Thread.new do
            slave.execute ".buffet/buffet-worker #{server_addr} #{Settings.framework}"
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
        results += "#{key}: #{value}\n"
      end

      results += "\n"
      mins, secs = (@end_time - @start_time).divmod(60)
      results += "Buffet was consumed in %d mins %d secs\n" % [mins, secs]
    end

    def next_file
      @lock.synchronize do
        @files_to_run.shift
      end
    end

    def example_passed(details)
      @lock.synchronize do
        @stats[:examples] += 1
      end

      @pass_list.push({:description => details[:description]})
    end

    def example_failed(details)
      @lock.synchronize do
        @stats[:examples] += 1
        @stats[:failures] += 1

        backtrace ||= "No backtrace found."

        @failure_list.push(details)
      end
    end

    def server_addr
      @drb_server.uri
    end

    def start_service
      @drb_thread = Thread.new do
        @drb_server = DRb.start_service('druby://0.0.0.0:0', self)
        DRb.thread.join
      end
    end

    def stop_service
      DRb.stop_service
      @drb_thread.join
    end

    def failures
      @failure_list
    end

    def passes
      @pass_list
    end

    def hostname
      result = Buffet.run! 'hostname'
      result.stdout.split('.').first
    end
  end
end
