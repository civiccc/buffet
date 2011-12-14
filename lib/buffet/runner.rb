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

    def slave_prepared slave
      Buffet.logger.info "#{slave.name} prepared"
    end

    def spec_taken slave, spec_file
      Buffet.logger.info "#{slave.name} took #{spec_file}"
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

    def slave_finished slave
      Buffet.logger.info "#{slave.name} finished"
    end

    def failures?
      @master.failures.any?
    end

    private

    def run_tests
      @master = Master.new @project, @slaves, @specs, self
      @master.run
    end

    def display_results
      results = []
      results << "\n"

      @master.stats[:slaves].each do |slave_name, slave_stats|
        results << "#{slave_name}:"
        slave_stats.each do |key, value|
          results << "\t#{key}: #{value}" unless key == :slave
        end
      end

      results << "Total Examples: #{@master.stats[:examples]}"
      results << "Total Pending:  #{@master.stats[:pending]}"
      results << "Total Failures: #{@master.stats[:failures]}"
      results << ''
      results << "Buffet consumed in #{@master.stats[:total_time]} seconds"

      unless @master.failures.empty?
        results << ''
        results << @master.failures.map do |failure|
          "#{failure[:description]}\n".red +
          "Slave: #{failure[:slave_name]}\n" +
          "Location: #{failure[:location]}\n" +
          "#{failure[:message]}\n" +
          "#{failure[:backtrace]}\n"
        end
      end

      puts results
    end
  end
end
