#!/usr/local/bin/ruby
$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/.."))

# The Buffet command line interface.
#
# Sinatra is unfortunately quiet about a lot of errors, so the CLI is a boon to
# bug hunting.

require 'buffet/buffet'
require 'json'
require 'buffet/settings'
require 'buffet/commit_watcher'

module Buffet
  class CLI
    def initialize
      # Set some initial settings. These may be changed by process_args.
      @branch = "master"
      @watch = false
      @skip_setup = false
      @dont_run_migrations = true
      @verbose = true
      @settings = false

      process_args

      if @settings
        editor = ENV["EDITOR"] || "vi"
        system "#{editor} #{SETTINGS_FILE}"
        return
      end

      if not @watch
        puts "Running Buffet on branch #{@branch}."

        buffet = Buffet.new(Settings.get["repository"], {:verbose => @verbose})
        buffet.run(@branch, {:skip_setup => @skip_setup, :dont_run_migrations => @dont_run_migrations})
      else
        puts "Watching #{Settings.get["repository"]}/master. Ctrl-C to quit."

        settings = { :username   => Settings.get["github"]["username"], 
                     :token      => Settings.get["github"]["token"],
                     :owner      => Settings.get["github"]["owner"],
                     :repository => Settings.get["github"]["repository"],
                     :branch     => Settings.get["token"]
                   }

        CommitWatcher.watch settings do
          puts "New commit on master."

          buffet = Buffet.new(Settings.get["repository"], {:verbose => @verbose})
          buffet.run(@branch, {:skip_setup => false, :dont_run_migrations => false})
        end
      end
    end

    def process_args
      ARGV.each do |arg|
        if arg == "--help"
          puts "Buffet: a distributed testing framework for Ruby."
          puts ""
          puts "Usage: bundle exec ruby lib/buffet/cli.rb [flags]"
          puts ""
          puts "Flags"
          puts ""
          puts "\t--settings"
          puts "\t\tConfigure Buffet. You can change the tested repository,"
          puts "\t\tcampfire settings, and other things here."
          puts ""
          puts "\t--watch"
          puts "\t\tWatch the repo specified in settings.yml. Tests will be"
          puts "\t\trun immediately, and every time someone pushes to master."
          puts ""
          puts "\t--skip-setup"
          puts "\t\tSkip the setup step and just run tests."
          puts ""
          puts "\t--dont-run-migrations"
          puts "\t\tDon't run database migrations."
          puts ""
          puts "\t--branch=some_branch"
          puts "\t\tRun tests on branch some_branch."
          puts ""
          puts "\t--quiet"
          puts "\t\tDon't output anything while testing, except ./F."

          exit 0
        elsif arg == "--watch"
          @watch = true
        elsif arg == "--settings"
          @settings = true
        elsif arg == "--skip-setup"
          @skip_setup = true
        elsif arg == "--dont-run-migrations"
          @dont_run_migrations = false
        elsif arg == "--quiet"
          @verbose = false
        elsif arg.match(/^--branch=/)
          @branch = arg.gsub(/--branch=([\w*])/, "\\1")
        end
      end
    end
  end
end
