$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/.."))

require 'buffet'

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

      prepare_slaves
      run_tests
      display_results
    end

    private

    def prepare_slaves
      puts "Preparing workers for testing..."

      threads = @slaves.map do |slave|
        Thread.new do
          prepare_slave slave
        end
      end

      threads.each do |thread|
        thread.join
      end
    end

    def prepare_slave slave
      slave.execute 'mkdir -p .buffet'

      @project.sync_to slave
      slave.execute_in_project Settings.prepare_script if Settings.has_prepare_script?

      # Copy support files so they can be run on the remote machine
      slave.scp File.dirname(__FILE__) + '/../../support',
                @project.support_dir_on_slave, :recurse => true
    end

    def run_tests
      puts "Running tests..."
      @master = Master.new @project, @slaves, @specs
      @master.run
    end

    def display_results
      results = []
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
