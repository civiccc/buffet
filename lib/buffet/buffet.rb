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

PID_FILE = "/tmp/#{Buffet::Settings.root_dir_name}-buffet.pid"

module Buffet
  # This is the core Buffet class. It uses Setup and Master to bring the working
  # directory up to sync and to run tests remotely, respectively. It exposes 
  # some helpful methods to give immediate information about the state of the 
  # tests and other relevant information.
  class Buffet
    include Memoize

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
      if Settings.get["hosts"].length == 0
        @status.set "Buffet was unable to access any machines you listed. You should run buffet --check-mode."
        return
      end

      initialize_chat

      ensure_only_runner do
        @status.set "Buffet is starting..."

        chat "Buffet is running on #{@repo} : #{branch}."

        if not kwargs[:skip_setup]
          @state = :setup
          @setup = Setup.new Settings.working_dir, hosts, @status, @repo
          @setup.run kwargs[:dont_run_migrations], branch
        end

        @state = :testing
        @master = Master.new Settings.working_dir, hosts, @status
        @master.run

        display_failures

        @state = :finding_regressions
        @status.set "Looking for regressions..."

        @regression_finder = Regression.new(@master.passes, @master.failures)
        puts @regression_finder.regressions

        @state = :not_running
        @status.set @master.failures.length > 0 ? "Go fix your bugs." : "All tests pass!"
      end
    end

    #####################
    # CHAT  INTEGRATION #
    #####################

    def initialize_chat
      @using_chat = Settings.get["use_campfire"]

      if @using_chat
        Campfire.connect_and_login
      end
    end

    # This is like a higher priority @status.set. It's currently reserved for
    # starting and finishing a test run.
    def chat(message)
      if @using_chat
        if message.include? "\n"
          Campfire.paste message
        else
          Campfire.speak message
        end
      else
        @status.set message
      end
    end


    ######################
    #     HOST SETUP     #
    ######################
    
    def check_hosts
      # Have access to each host?

      if Settings.get["hosts"] == nil
        puts "No hosts have been listed in the settings file. Run buffet --settings."
        exit 0
      end

      Settings.get["hosts"].each do |host|
        next if `ssh buffet@#{host} -o PasswordAuthentication=no 'echo aaaaa'`.include? "aaaaa"

        puts "Unable to access #{host}."

        Settings.get["hosts"].delete host
      end
    end

    ######################
    # ENSURE EXCLUSIVITY #
    ###################### 

    # Ensure that only one instance of the block passed in runs at any time,
    # across the entire machine.
    def ensure_only_runner
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
        puts "#{PID_FILE} exists, which indicates to me that Buffet is already"
        puts "running. If you have reason to think it's not, you can delete the"
        puts "file."
        return
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

    # Prettyprint the failures that Master has found.
    def display_failures
      if @master.failures.length == 0
        chat "All tests pass!"
      else
        rev = `cd working-directory && git rev-parse HEAD`.chomp
        nice_output = @master.failures.map do |fail|
          "#{fail[:header]} FAILED.\nLocation: #{fail[:location]}\n\n"
        end.join ""
        nice_output = "On revision #{rev}:\n\n" + nice_output
        chat "#{nice_output}"
      end
    end

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
