#!/usr/bin/env ruby

require 'ftools'
require 'benchmark'

$LOAD_PATH.push(File.expand_path(File.dirname(__FILE__)))

require 'wopen3'
require 'master'
require 'settings'
require 'campfire'
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

    # Maintains a current status message, along with an optional progress amount
    # (which is generically displayed as (x of y), for example (5 of 100).
    # The progress amount gets reset when you set a new message. 
    class StatusMessage
      def initialize should_display
        @message = ""
        @show_progress = false
        @progress = 0
        @max_progress = 0
        @should_display = should_display
      end

      def set(message)
        @message = message
        @show_progress = false

        if @should_display
          puts get
        end
      end

      def get
        if @show_progress
          "#{@message} (#{@progress} of #{@max_progress})"
        else
          "#{@message}"
        end
      end

      def start_progress(max_progress)
        @show_progress = true
        @max_progress = max_progress
        @progress = 0
        if @should_display
          puts get
        end
      end

      def increase_progress
        @progress += 1
        if @should_display
          puts get
        end
      end
    end


    # Initialize contains stuff that can be done preliminarily; that is, it's not
    # imperative that we have to be running a test in order to run this function. 
    # Right now, it just sets instance variables and clones the working directory
    # if it doesn't already exist.
    def initialize 
      @running = false
      @status = StatusMessage.new true
      @buffet_dir = File.expand_path(File.dirname(__FILE__) + "/../..")
      @target_dir = "working-directory"
      @progress = 0

      @repo = Buffet.settings['repository']

      if `ps -ef | grep ssh-agent | grep $USER | grep -L 'grep'`.length == 0
        #TODO: Maybe some sort of warning message. 
      end

      if not directory_exists? @target_dir
        @status.set "Cloning #{@repo}. This will only happen once.\n"

        run_open3(*"git clone #{@repo} #{@target_dir}".split(" "))
      end

      memoize :hosts
    end

    def get_repo
      @repo
    end

    def running?
      @running
    end

    # Run the command COMMAND, and every time an output line matches PROGRESS_REGEX,
    # add to @progress.
    #
    def increase_progress(progress_regex, expected, command)
      @status.start_progress(expected)
      # It's necessary to split along && because passing in multiple commands to
      # popen3 does not appear to work.
      command.split('&&').map do |command|
        Wopen3.popen3(*command.split(" ")) do |stdin, stdout, stderr|
          Thread.new(stdout) do |out|
            out.each do |line|
              if progress_regex =~ line
                @status.increase_progress
              end
            end
          end
        end
      end

      if $?.exitstatus != 0
        @status.set "Command #{command} failed."
      end
    end

    # Grab all hosts from the yml file.
    def hosts
      Buffet.settings['hosts']
    end

    # Install bundles on all remote machines.
    def bundle_install target_dir
      hosts.each do |host|
        @status.set "Bundle install on #{host}"
        `sh -c "ssh buffet@#{host} 'cd ~/buffet/#{target_dir} && bundle install --without production --path ~/buffet-gems'" &`
      end
    end

    # Synchronize this directory to all hosts.
    def sync_hosts(dir_to_sync)
      hosts.each do |host|
        @status.set "Syncing on #{host}"
        `rsync -aqz --delete --exclude=tmp --exclude=log --exclude=doc --exclude=.git #{dir_to_sync} -e "ssh " buffet@#{host}:~/ &`
      end
    end

    # This method is used by the webserver to query our current status. It must 
    # be called asynchronously since run() is blocking
    def get_status
      if @server
        tests = @server.get_current_stats[:examples]

        @status.get + "Tests run: <b>" + tests.to_s + " (#{ tests * 100 / @server.num_tests}%).</b> Failures: <b>" + @server.get_current_stats[:failure_count].to_s + "</b>"
      else
        @status.get
      end
    end

    def list_branches
      Dir.chdir(@target_dir) do
        `git branch -a`
      end
    end

    # Run the tests. There's lots of setup required before we can actaully run
    # them, including grabbing the latest version, installing gems, etc.
    def run(branch="master")
      @branch = branch

      @running = true
      begin # Make sure we always dispose of PID_FILE

        # Only one instance of Buffet should be running at any time.
        if File.exists?(PID_FILE)
          # Maybe we should do something like if `ps aux | grep buffet | 
          # grep #{File.open(PID_FILE).chomp}`.length == 0 then `rm #{PID_FILE}.
          # The hope is that this is rare enough that we don't have to worry.

          exit 1
        else
          File.open(PID_FILE, 'w') do |fh|
            fh.write(Process.pid)
          end
        end

        remote = 'origin'

        output, errors, rev = '', '', ''
        time = Benchmark.realtime do

          Dir.chdir(@target_dir) do
            `git fetch #{remote}`

            rev = `git rev-parse #{remote}/#{@branch}`.chomp # Get hash
            if $?.exitstatus != 0
              # probably got passed a SHA-1 hash instead of a branch name
              rev = `git rev-parse #{@branch}`.chomp
            end
            expect_success('Rev-parse failed', rev)

            @status.set "Updating local repository.\n"
            result = increase_progress(/a/, 30, 
                         "git checkout #{rev} &&
                          git reset --hard #{rev} &&
                          git clean -f &&
                          git submodule update --init &&
                          git submodule foreach git reset --hard HEAD &&
                          git submodule foreach git clean -f".gsub(/\n/, ''))
            expect_success("Failed to clone local repository.", result)

            ENV['RAILS_ENV'] = 'test'

            @status.set "Updating local gems.\n"
            output, errors = run_open3('bundle', 'install', '--without', 'production', '--path', '~/buffet-gems')
            expect_success("Failed to bundle install on local machine.", output + errors)

            if not File.exist? "./bin/db_setup"
              #@status.set "bin/db_setup not found in repository; copying Buffet's default script.\n"
              
              File.copy(File.join(@buffet_dir, "db_setup"), "./bin/db_setup")
            end
            @status.set "Running bin/db_setup\n"

            increase_progress /^== [\d]+ /, 1120, "./bin/db_setup " + hosts.join(" ")

            # TODO: A standardized way to exit on script failure.
            if $?.exitstatus != 0
              return
            end
          end

          @status.set "Copying Buffet to hosts."
          sync_hosts @buffet_dir

          @status.set "Running bundle install on hosts."
          bundle_install @target_dir

          #Finally, we can run tests.

          @status.set ""

          @server = Buffet::Master.new @target_dir, hosts
          @status.set @server.run
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
      if @server
        @server.get_failures_list
      else
        []
      end
    end

    def num_tests
      if @server
        @server.num_tests
      else
        0
      end
    end
  end
end

if __FILE__ == $0
  b = Buffet::Runner.new
  b.run ARGV.first
end
