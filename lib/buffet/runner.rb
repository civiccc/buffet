require 'buffet'
require 'colorize'

module Buffet
  class Runner
    def initialize
      @project = Settings.project
    end

    def run specs = nil
      @specs = specs
      raise 'No specs found' if @specs.empty?

      @slaves = Settings.slaves
      raise 'No slaves defined in settings.yml' if @slaves.empty?

      Buffet.logger.info "Starting Buffet test run"
      puts "Running Buffet..."

      run_tests
      display_results
    end

    def example_passed
      print '.'.green
      STDOUT.flush
    end

    def example_failed
      print 'F'.red
      STDOUT.flush
    end

    def example_pending
      print '*'.yellow
      STDOUT.flush
    end

    private

    def run_tests
      @master = Master.new @project, @slaves, @specs, self
      @master.run
    end

    def display_results
      results = []
      results << "\n"
      @master.stats.each do |key, value|
        results << "#{key}: #{value}"
      end

      results << "Buffet consumed in #{@master.stats[:total_time]} seconds"

      unless @master.failures.empty?
        results << @master.failures.map do |failure|
          "#{failure[:header]} FAILED.\n" +
          "Location: #{failure[:location]}\n" +
          "#{failure[:message]}\n" +
          "#{failure[:backtrace]}\n"
        end
      end

      puts results
    end
  end
end
