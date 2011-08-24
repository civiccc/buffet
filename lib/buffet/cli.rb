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
require 'optparse'

module Buffet
  class CLI
    def initialize args
      # Set some initial settings. 
      @check_mode = false
      @branch = "master"
      @watch = false
      @skip_setup = false
      @dont_run_migrations = true
      @verbose = true
      @settings = false

      opts = OptionParser.new do |opts|
        opts.banner = "Usage: buffet.rb [options]"
        
        opts.on "--watch", "Watch a repository" do
          @watch = true
        end
        opts.on "--settings", "Edit Buffet settings." do
          editor = ENV["EDITOR"] || "vi"
          system "#{editor} #{SETTINGS_FILE}"
          return
        end
        opts.on "--check-mode", "Ensure all machines are set up properly." do
          @check_mode = true
        end
        opts.on "--skip-setup", "Only run tests." do
          @skip_setup = true
        end
        opts.on "--dont-run-migrations", "Don't run migrations." do
          @dont_run_migrations = false
        end
        opts.on "--quiet", "Don't output excessively." do
          @verbose = false
        end
        opts.on "--branch BRANCH", "Run on a specific branch" do |branch|
          @branch = branch
        end
      end.parse!(args)
     
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
  end
end
