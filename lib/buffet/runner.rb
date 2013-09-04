require 'buffet'
require 'colorize'
require 'fileutils'

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

    def slave_prepare_failed slave, exception
      Buffet.logger.warn "#{slave.name} preparation failed: #{exception}"
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
      gather_junit slave if !!Settings['gather_junit']
    end

    def failed?
      @master.failures.any? || no_examples_run?
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

        if @master.slave_exceptions[slave_name]
          results << "\tFailed to prepare"
          next
        end

        slave_stats.each do |key, value|
          results << "\t#{key}: #{value}" unless [:slave, :specs].include?(key)
        end

        if slave_stats[:failures] > 0
          results << "\tSpec order (use to help reproduce spurious failures):"
          results << "\t  #{slave_stats[:specs].join("\n\t  ")}"
        end
      end

      results << ''
      results << "Total Examples: #{@master.stats[:examples]}"
      results << "Total Pending:  #{@master.stats[:pending]}"
      results << "Total Failures: #{@master.stats[:failures]}"
      results << "Total Spurious Failures: #{@master.stats[:spurious_failures]}"
      results << "Buffet consumed in #{@master.stats[:total_time]} seconds"

      unless @master.slave_exceptions.empty?
        results << '' << 'Slave preparation failures:'.red
        results << @master.slave_exceptions.map do |slave, ex|
          "#{slave}:\n".yellow +
          "#{ex}" + (ex.backtrace ? ex.backtrace.join("\n") : 'No backtrace')
        end
      end

      if @master.failures.any?
        results << '' << 'SPEC FAILURES:'.red
        results << ('=' * 80).red
        results << @master.failures.map do |failure|
          example_details(failure)
        end
      elsif @master.spurious_failures.any?
        results << '' << 'SPURIOUS FAILURES:'.yellow
        results << ('-' * 80).yellow
        results << @master.spurious_failures.map do |spurious_failure|
          example_details(spurious_failure)
        end
      elsif no_examples_run?
        results << '' << 'No examples were run!'.red
      end

      puts results
    end

    def example_details(details)
      "#{details[:description]}\n".red +
      "Slave: #{details[:slave_name]}\n" +
      "Location: #{details[:location]}\n" +
      "#{details[:message]}\n".yellow +
      "#{details[:backtrace]}\n"
    end

    def no_examples_run?
      @master.stats[:examples] - @master.stats[:pending] == 0
    end

    def gather_junit slave
      # Jenkins tells us where we are running
      workspace = ENV['WORKSPACE'] || './'
      FileUtils.mkdir_p File.join(workspace, 'reports')

      # Copy the junit results from the slave into reports/foo@bar/
      # Configure jenkins to read reports/**/*.xml
      Buffet.run! *%W[
        rsync -aqz --delete
        -e ssh
        #{slave.user_at_host}:#{slave.project.directory_on_slave}/spec/reports/
        #{workspace}/reports/#{slave.name}/
      ]
    rescue CommandError
      Buffet.logger.warn "Failed to collect junit report from #{slave.name}"
    end
  end
end
