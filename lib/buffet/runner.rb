#!/usr/bin/env ruby

require 'ftools'
require 'benchmark'

require 'wopen3'
require 'buffet/master'
require 'buffet/settings'
require 'buffet/campfire'
require 'buffet/status_message'
require 'memoize'
include Memoize


PID_FILE = "/tmp/buffet.pid"

def run_open3(*args)
  output, errors = '', ''
  Wopen3.popen3(*args) do |stdin, stdout, stderr|
    threads = []
    threads << Thread.new(stdout) do |out|
      out.each do |line|
        output << line
      end
    end
    threads << Thread.new(stderr) do |err|
      err.each do |line|
        errors << line
        puts "* #{line}"
      end
    end
  end
  return output, errors
end

def expect_success(failure_msg, diagnostic_output)
  if $?.exitstatus != 0
    Campfire.speak(tee(failure_msg))
    Campfire.paste(tee(diagnostic_output))
    exit 1
  end
end

# Like "tee" on the commandline, this method just pipes from "stdin" (the
# method argument) to "stdout" (the return value), while writing a copy
# somewhere else; in this case the "somewhere else" is the console, where
# the output will be captured and logged by the detour Sinatra app to aid
# in problem diagnosis.
def tee(string)
  string.lines.each do |line|
    puts "> #{line}"
  end
  string
end

def directory_exists?(path)
  File.exists? path and File.directory? path
end

module Buffet
  class Runner

    # Initialize contains stuff that can be done preliminarily; that is, it's not
    # imperative that we have to be running a test in order to run this function. 
    # Right now, it just sets instance variables and clones the working directory
    # if it doesn't already exist.
    def initialize 
      @running = false
      @status = Buffet::StatusMessage.new true
      @buffet_dir = File.expand_path(File.dirname(__FILE__) + "/../..")
      @working_dir = "working-directory"
      @progress = 0

      @repo = Buffet.settings['repository']

      if `ps -ef | grep ssh-agent | grep $USER | grep -L 'grep'`.length == 0
        #TODO: Maybe some sort of warning message. 
      end

      if not directory_exists? @working_dir
        @status.set "Cloning #{@repo}. This will only happen once.\n"

        run_open3(*"git clone #{@repo} #{@working_dir}".split(" "))
      end

      memoize :hosts
    end

    def get_repo
      @repo
    end

    def running?
      @running
    end

    def testing?
      @master
    end

    def hosts
      Buffet.settings['hosts']
    end

    # Install bundles on all remote machines.
    def bundle_install working_dir
      hosts.each do |host|
        @status.set "Bundle install on #{host}"
        `sh -c "ssh buffet@#{host} 'cd ~/buffet/#{working_dir} && bundle install --without production --path ~/buffet-gems'" &`
      end
    end

    # Synchronize this directory to all hosts.
    def sync_hosts
      threads = []

      @status.set "Syncing #{hosts.join(", ")}"

      hosts.each do |host|
        threads << Thread.new do 
          `rsync -aqz --delete --exclude=tmp --exclude=log --exclude=doc --exclude=.git #{@buffet_dir} -e "ssh " buffet@#{host}:~/`
        end
      end

      threads.each do |thread|
        puts "Joined."
        thread.join
      end
    end

    # This method is used by the webserver to query our current status. It must 
    # be called asynchronously since run() is blocking
    def get_status
      if @master
        tests = @master.get_current_stats

        [tests[:examples], tests[:examples] * 100 / num_tests, tests[:failure_count]]
      else
        @status.get
      end
    end

    def update_working_dir remote, branch
      Dir.chdir(@working_dir) do
        `git fetch #{remote}`

        rev = `git rev-parse #{remote}/#{branch}`.chomp # Get hash
        if $?.exitstatus != 0
          # probably got passed a SHA-1 hash instead of a branch name
          rev = `git rev-parse #{branch}`.chomp
        end
        expect_success('Rev-parse failed', rev)

        @status.set "Updating local repository.\n"
        @status.increase_progress(/a/, 30, 
                     "git checkout #{rev} &&
                      git reset --hard #{rev} &&
                      git clean -f &&
                      git submodule update --init &&
                      git submodule foreach git reset --hard HEAD &&
                      git submodule foreach git clean -f".gsub(/\n/, ''))
        # expect_success("Failed to clone local repository.", result)

        ENV['RAILS_ENV'] = 'test'

        @status.set "Updating local gems.\n"
        output, errors = run_open3('bundle', 'install', '--without', 'production', '--path', '~/buffet-gems')
        expect_success("Failed to bundle install on local machine.", output + errors)

        @status.set "Running db_setup\n"
        @status.increase_progress /^== [\d]+ /, 1120, "./../db_setup " + hosts.join(" ")
        expect_success("Failed to bundle install on local machine.", output + errors)
      end
    end

    #TODO: This shouldn't be here...
    def list_branches
      Dir.chdir(@working_dir) do
        `git branch -a`
      end
    end

    # Only one instance of Buffet should be running at any time.
    def ensure_only_instance
      if File.exists?(PID_FILE)
        # Maybe we should do something like if `ps aux | grep buffet | 
        # grep #{File.open(PID_FILE).chomp}`.length == 0 then `rm #{PID_FILE}.
        # The hope is that this is rare enough that we don't have to worry.

        puts "Buffet is already running. Exiting."
        exit 1
      else
        File.open(PID_FILE, 'w') do |fh|
          fh.write(Process.pid)
        end
      end
    end

    # Run the tests. There's lots of setup required before we can actaully run
    # them, including grabbing the latest version, installing gems, etc.
    def run(branch="master")
      remote = 'origin'
      @running = true
      begin # Make sure we always dispose of PID_FILE
        ensure_only_instance

        output, errors, rev = '', '', ''
        time = Benchmark.realtime do
          update_working_dir remote, branch

          @status.set "Copying Buffet to hosts."
          sync_hosts

          @status.set "Running bundle install on hosts."
          bundle_install @working_dir

          #Finally, we can run tests.

          @status.set ""

          @master = Buffet::Master.new @working_dir, hosts
          @status.set @master.run
          @status.set output + "\n"
        end
      ensure
        @running = false
        if File.read(PID_FILE).to_i == Process.pid
          File.delete(PID_FILE)
        end
      end
    end

    def get_failures
      if @master
        @master.get_failures_list
      else
        []
      end
    end

    # This is RSpec specific.
    def num_tests
      #TODO: maybe specify
      `grep -r "  it" #{@working_dir}/spec/ | wc`.to_i
    end

    memoize :num_tests
  end
end

if __FILE__ == $0
  b = Buffet::Runner.new
  b.run ARGV.first
end
