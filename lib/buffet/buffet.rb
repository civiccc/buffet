$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/.."))

require 'ftools'

require 'buffet/master'
require 'buffet/settings'
require 'buffet/status_message'
require 'buffet/runner'

require 'memoize'
include Memoize

PID_FILE = "/tmp/buffet.pid"
SETTINGS_FILE = File.expand_path('../../settings.yml', File.join(File.dirname(__FILE__)))

module Buffet
  class Buffet

    #TODO: Duplication with settings.rb.
    def settings
      @settings ||= YAML.load_file(SETTINGS_FILE)
    end

    #TODO: Util?
    def directory_exists?(path)
      File.exists? path and File.directory? path
    end

    def initialize repo
      @status = StatusMessage.new true
      @repo = repo
      @working_directory = ('working-directory')
      @state = :not_running
      @threads = []

      if `ps -ef | grep ssh-agent | grep $USER | grep -L 'grep'`.length == 0
        #TODO: Maybe some sort of warning message. 
      end

      if not directory_exists? @working_directory
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
      settings['hosts']
    end

    def list_branches
      Dir.chdir(@working_directory) do
        `git branch -a`
      end
    end
    memoize :list_branches

    def num_tests
      # This is RSpec specific.
      #TODO: maybe specify
      `grep -r "  it" #{@working_directory}/spec/ | wc`.to_i
    end

    memoize :num_tests

    # Only one instance of Buffet should be running at any time. The next three
    # functions help manage the PID_FILE which ensures this.
    def running?
      # Maybe we should do something like if `ps aux | grep buffet | 
      # grep #{File.open(PID_FILE).chomp}`.length == 0 then `rm #{PID_FILE}.
      # The hope is that this is rare enough that we don't have to worry.
      return File.exists?(PID_FILE)
    end

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

    def run
      if running? 
        puts "Buffet is already running."
        exit 1
      end

      @threads << Thread.new do
        begin
          write_pid
      
          @state = :setup
          setup = Runner.new @working_directory, hosts, @status, @repo
          setup.run "master"

          @state = :testing
          master = Master.new @working_directory, hosts, @status
          master.run #RFCTR: This method does not take any args right now
        
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
  end
end

b = Buffet::Buffet.new "git@github.com:causes/buffet.git"
b.run
b.wait_until_done
