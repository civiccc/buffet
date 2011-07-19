$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/.."))

require 'ftools'
require 'fileutils'

require 'buffet/master'
require 'buffet/settings'
require 'buffet/status_message'
require 'buffet/setup'

require 'memoize'
include Memoize

PID_FILE = "/tmp/buffet.pid"
SETTINGS_FILE = File.expand_path('../../settings.yml', File.join(File.dirname(__FILE__)))

module Buffet
  class Buffet
    def initialize repo
      @status = StatusMessage.new true
      @repo = repo
      @working_directory = './working-directory'
      @state = :not_running
      @threads = []

      if not File.directory? @working_directory
        if `ps -ef | grep ssh-agent | grep $USER | grep -L 'grep'`.length == 0
          puts "You should run ssh-agent so you don't see so many password prompts."
        end

        @status.set "Cloning #{@repo}. This will only happen once.\n"

        `git clone #{@repo} #{@working_directory}`
      end
    end

    def repo
      @repo
    end

    def running?
      @state != :not_running
    end

    def testing?
      @state == :testing
    end

    def hosts
      Settings.get['hosts']
    end

    def list_branches
      Dir.chdir(@working_directory) do
        `git branch -a`
      end
    end
    memoize :list_branches

    def num_tests
      # This is RSpec specific.
      `grep -r "  it" #{@working_directory}/spec/ | wc`.to_i
    end
    memoize :num_tests

    def write_pid
      File.open(PID_FILE, 'w') do |fh|
        fh.write(Process.pid)
      end
    end

    def clear_pid
      if File.read(PID_FILE).to_i == Process.pid
        File.delete(PID_FILE)
      end
    end

    def run(skip_setup=false)
      if File.exists?(PID_FILE)
        if `ps aux | grep buffet | grep -v grep | grep #{File.open(PID_FILE).read}`.length == 0
          # Buffet isn't running, but the PID_FILE exists.
          # Get rid of it.
          FileUtils.rm(PID_FILE)
        else
          puts "Buffet is already running. Hold your horses."
          exit 1
        end
      end

      @threads << Thread.new do
        begin
          write_pid
      
          @state = :setup
          @setup = Setup.new @working_directory, hosts, @status, @repo
          @setup.run "master"

          @state = :testing
          @master = Master.new @working_directory, hosts, @status
          @master.run
        
          @state = :not_running
        ensure
          clear_pid
        end
      end
    end

    def wait_until_done
      @threads.each do |thread|
        thread.join
      end
    end

    def get_status
      @status
    end

    def get_failures
      if @state == :testing
        @master.failures
      else
        []
      end
    end
  end
end
