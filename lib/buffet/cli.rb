#!/usr/local/bin/ruby
$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/.."))

# The Buffet command line interface.
#
# Sinatra is unfortunately quiet about a lot of errors, so the CLI is a boon to
# bug hunting.

require 'buffet/buffet'
require 'json'
require 'buffet/settings'

module Buffet
  class CLI
    def initialize
      # Set some initial settings. These may be changed by process_args.
      @branch = "master"
      @watch = false
      #TODO: Annoying how one is yes and one is no.
      @skip_setup = false
      @dont_run_migrations = true

      process_args

      if not @watch
        puts "Running Buffet on branch #{@branch}."

        buffet = Buffet.new(Settings.get["repository"], true)
        buffet.run(@branch, {:skip_setup => @skip_setup, :dont_run_migrations => @dont_run_migrations})
      else
        puts "Watching #{Settings.get["repository"]}/master. Ctrl-C to quit."

        watch
      end
    end

    def watch
      buffet_lock = Mutex.new

      old_commit_message = ""
      while true
        api_call = "curl -u '#{Settings.get['github']['username']}/token:#{Settings.get['github']['token']}' 'https://github.com/api/v2/json/commits/list/#{Settings.get['github']['owner']}/#{Settings.get['github']['repository']}/master'"

        commit_message = JSON.parse(`#{api_call}`)["commits"].first["message"]

        if commit_message != old_commit_message 
          puts "New commit on master."

          buffet = Buffet.new(Settings.get["repository"], true)
          buffet.run(@branch, {:skip_setup => false, :dont_run_migrations => false})
        end

        old_commit_message = commit_message
        sleep 2
      end
    end

    def process_args
      ARGV.each do |arg|
        if arg == "--help"
          puts "Buffet command line interface"
          puts ""
          puts "Usage: bundle exec ruby lib/buffet/cli.rb [flags]"
          puts ""
          puts "Flags"
          puts "\t--watch"
          puts "\t\tWatch the repo specified in settings.yml. This will not run"
          puts "\t\tBuffet initially. Instead, the tests will be run every time" 
          puts "\t\tsomeone pushes to master."
          puts ""
          puts "\t--skip-setup"
          puts "\t\tSkip the setup step and just run tests."
          puts ""
          puts "\t--dont-run-migrations"
          puts "\t\tDon't run database migrations."
          puts ""
          puts "\t--branch=some_branch" #TODO
          puts "\t\tRun tests on branch some_branch."
          puts ""
          puts "\t--quiet" #TODO
          puts "\t\tDon't output anything while testing, except ./F."

          exit 0
        elsif arg == "--watch"
          @watch = true
        elsif arg == "--skip-setup"
          @skip_setup = true
        elsif arg == "--dont-run-migrations"
          @dont_run_migrations = false
        elsif arg.match(/^--branch=/)
          @branch = arg.gsub(/--branch=([\w*])/, "\\1")
        end
      end
    end
  end

  CLI.new
end
