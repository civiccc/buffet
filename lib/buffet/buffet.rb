$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/.."))

require 'ftools'
require 'fileutils'

require 'buffet/campfire'
require 'buffet/master'
require 'buffet/settings'
require 'buffet/status_message'
require 'buffet/setup'
require 'buffet/regression'

require 'memoize'
include Memoize

PID_FILE = "/tmp/#{Buffet::Settings.root_dir_name}-buffet.pid"
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
    # specified in settings.yml into working-directory if necessary. Also
    # verifies that all hosts are able to run Buffet.
    #
    # Initialize will NOT begin testing.
    def initialize repo, kwargs
      @status = StatusMessage.new kwargs[:verbose]
      @repo = repo
      @state = :not_running
      @threads = []

      check_hosts
    end


    # Run sets up and tests the working directory.
    # 
    # Run takes keyword arguments. 
    #
    #   :skip_setup => Don't do any preliminary setup with the working directory.
    #       This is more helpful for testing then actually running Buffet, since
    #       in theory you should have changed SOMETHING in Buffet between tests.
    #
    #   :dont_run_migrations => Don't run the database migrations.
    def run branch, kwargs={}
      Campfire.connect_and_login

      @branch = branch
      ensure_only_one do
        @status.set "Buffet is starting..."

        Campfire.speak "Buffet is running on #{@repo} : #{branch}."

        if not kwargs[:skip_setup]
          @state = :setup
          @setup = Setup.new Settings.working_dir, hosts, @status, @repo
          @setup.run kwargs[:dont_run_migrations], @branch
        end

        @state = :testing
        @master = Master.new Settings.working_dir, hosts, @status
        @master.run

        if @master.failures.length == 0
          Campfire.paste "All tests pass!"
        else
          rev = `cd working-directory && git rev-parse HEAD`.chomp
          nice_output = @master.failures.map do |fail|
            "#{fail[:header]} FAILED.\nLocation: #{fail[:location]}\n\n"
          end.join ""
          nice_output = "On revision #{rev}:\n\n" + nice_output
          Campfire.paste "#{nice_output}"
        end

        @state = :finding_regressions
        @status.set "Looking for regressions..."

        @regression_finder = Regression.new(@master.passes, @master.failures)
        puts @regression_finder.regressions

        @state = :not_running
        @status.set "Done"
      end
    end

    ######################
    #     HOST SETUP     #
    ######################
    
    def check_hosts
      if not File.exists? "#{Settings.home_dir}/.ssh/id_rsa.pub"
        puts "You should create a ssh public/private key pair before running"
        puts "Buffet."
      end
      shown_error = false

      # Create a buffet user on each uninitialized host.
      Settings.get["hosts"].each do |host|
        # id writes to stderr on fail, so we need to redirect.
        if `ssh root@#{host} 'id buffet 2>&1'`.include? "No such user"
          if not shown_error
            puts "#############################################################"
            puts "Buffet user not found on #{host}."
            puts ""
            puts "Buffet will need the root password to every machine you plan"
            puts "to use as a host. This will be the only time the password is"
            puts "needed."
            puts ""
            puts "Buffet needs root access only on the first run, as it needs"
            puts "to create buffet users on each machine."
            puts "#############################################################"

            shown_error = true
          end

          `scp ~/.ssh/id_rsa.pub root@#{host}:id_rsa_buffet.pub`
          `ssh root@#{host} 'adduser buffet && mkdir -p ~buffet/.ssh && cat ~/id_rsa_buffet.pub >> ~buffet/.ssh/authorized_keys && chmod 644 ~buffet/.ssh/authorized_keys'`
        end
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
      @master ? @master.failures : []
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
