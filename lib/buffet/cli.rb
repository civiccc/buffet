#!/usr/local/bin/ruby
$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/.."))

# The Buffet command line interface.
#
# Sinatra is unfortunately quiet about a lot of errors, so the CLI is a boon to
# bug hunting.

require 'buffet/buffet'
require 'json'
require 'buffet/settings'
require 'buffet/remote_runner'
require 'buffet/checker'
require 'optparse'
require 'drb/drb'

module Buffet
  class CLI
    def initialize args
      # Set some initial settings. 
      @check_mode = false
      @branch = "master"
      @skip_setup = false
      @dont_run_migrations = false
      @verbose = true
      @settings = false

      opts = OptionParser.new do |opts|
        opts.banner = "Usage: buffet.rb [options]"

        opts.on "--listen", "Listen for buffet-remote requests" do
          @listen = true
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
     
      if @check_mode
        Checker.check @verbose
        return
      end

      normal_run = !@listen

      if normal_run
        puts "Running Buffet on branch #{@branch}."

        buffet = Buffet.new(Settings.get["repository"], {:verbose => @verbose})
        buffet.run(@branch, {:skip_setup => @skip_setup, :dont_run_migrations => @dont_run_migrations})
      elsif @listen
        someone_running = false

        puts "Listening for requests on #{LISTEN_URI}"

        DRb.start_service(LISTEN_URI, RemoteRunner.new)
        DRb.thread.join
      end
    end
  end
end
