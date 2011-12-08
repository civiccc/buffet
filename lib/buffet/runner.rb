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

      @master = Master.new @project, @slaves
      @master.run

      display_results
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
      slave.execute Settings.prepare_script if Settings.has_prepare_script?

      # Copy support files so they can be run on the remote machine
      slave.scp File.dirname(__FILE__) + '/../../support',
                @project.support_dir_on_slave, :recurse => true
    end

    def display_results
      results = ''
      @master.stats.each do |key, value|
        results += "#{key}: #{value}\n"
      end

      results += "\n"
      results += "Buffet consumed in %d seconds" % @master.stats[:total_time]

      if @master.failures.empty?
        puts "No failures"
      else
        results += @master.failures.map do |fail|
          "#{fail[:header]} FAILED.\nLocation: #{fail[:location]}"
        end.join "\n\n"
      end

      puts results
    end
  end
end
