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
  # This is the core Buffet class. It uses Setup and Master to bring the working
  # directory up to sync and to run tests remotely, respectively. It exposes 
  # some helpful methods to give immediate information about the state of the 
  # tests and other relevant information.
  class Buffet

    ################
    # CORE METHODS #
    ################

    # Initialize sets up preliminary data, and will clone the repository 
    # specified in settings.yml into working-directory if necessary.
    #
    # Initialize will NOT begin testing.
    def initialize repo
      @status = StatusMessage.new
      @repo = repo
      @state = :not_running
      @threads = []

      if not File.directory? Settings.working_dir
        if `ps -ef | grep ssh-agent | grep $USER | grep -L 'grep'`.length == 0
          puts "You should run ssh-agent so you don't see so many password prompts."
        end

        @status.set "Cloning #{@repo}. This will only happen once.\n"

        `git clone #{@repo} #{Settings.working_dir}`
      end
    end

    # Run is the core method of Buffet. It sets up and tests the working directory.
    def run(skip_setup=false)
      ensure_only_one do
        @status.set "Preliminary setup..."
        if not skip_setup
          @state = :setup
          @setup = Setup.new Settings.working_dir, hosts, @status, @repo
          @setup.run "master"
        end

        @state = :testing
        @master = Master.new Settings.working_dir, hosts, @status
        @master.run
      
        @state = :not_running
      end
    end

    ###################### 
    # ENSURE EXCLUSIVITY #
    ###################### 

    # Ensure that only one instance of the block passed in runs at any time,
    # across the entire machine.
    def ensure_only_one
      # We ensure exclusivity by writing a file to /tmp, and checking to see if it
      # exists before we start testing.
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

      if File.exists?(PID_FILE)
        if `ps aux | grep buffet | grep -v grep | grep #{File.open(PID_FILE).read}`.length == 0
          # Buffet isn't running, but the PID_FILE exists.
          # Get rid of it.
          FileUtils.rm(PID_FILE)
        else
          puts "Buffet is already running. Hold your horses."
          return
        end
      end

      begin
        write_pid
        yield
      ensure
        clear_pid
      end
    end

    ##################
    # TESTING STATUS #
    ##################

    # What is Buffet currently doing?
    # This method is only meaningful when called from a separate thread then 
    # the one running Buffet.
    def get_status
      @status
    end

    # An array of failed test cases.
    def get_failures
      if @state == :testing
        @master.failures
      else
        []
      end
    end

    # The URL of the respository.
    def repo
      @repo
    end

    # Is Buffet running (where running is either testing or setting up)?
    def running?
      @state != :not_running
    end

    # Is Buffet testing?
    def testing?
      @state == :testing
    end

    # List all the hosts (found in settings.yml)
    def hosts
      Settings.get['hosts']
    end

    # List all branches (found by asking the working directory)
    def list_branches
      Dir.chdir(Settings.working_dir) do
        `git branch -a`
      end
    end
    memoize :list_branches

    # Count the number of tests. Uses a heuristic that is not 100% accurate.
    def num_tests
      # This is RSpec specific.
      `grep -r "  it" #{Settings.working_dir}/spec/ | wc`.to_i
    end
    memoize :num_tests
  end
end
