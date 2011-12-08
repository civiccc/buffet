$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/.."))

require 'fileutils'

require 'buffet'

module Buffet
  class Runner
    def initialize
      @project = Settings.project
    end

    def run
      @slaves = Settings.slaves
      raise 'No slaves defined in settings.yml' if @slaves.empty?

      prepare_slaves

      master = Master.new @project, @slaves
      master.run

      display_results master.failures
    end

    private

    def prepare_slaves
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
      @project.sync_to slave
      slave.execute Settings.prepare_script

      # Copy support files so they can be run on the remote machine
      slave.scp File.dirname(__FILE__) + '/../../support',
                @project.support_dir_on_slave, :recurse => true
    end

    def before_test_run_script
      './bin/before-buffet-run'
    end

    def display_results failures
      if failures.empty?
        puts "No failures"
      else
        output = failures.map do |fail|
          "#{fail[:header]} FAILED.\nLocation: #{fail[:location]}"
        end
        puts output
      end
    end
  end
end
