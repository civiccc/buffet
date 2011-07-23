#!/usr/local/bin/ruby
$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/.."))

# The Buffet command line interface.
#
# Sinatra is unfortunately quiet about a lot of errors, so the CLI is a boon to
# bug hunting.

require 'buffet/buffet'
require 'buffet/settings'

module Buffet
  class CLI
    def initialize
      # Set some initial settings. These may be changed by process_args.
      @branch = "master"
      #TODO: Annoying how one is yes and one is no.
      @skip_setup = false
      @dont_run_migrations = true

      process_args

      puts "Running Buffet on branch #{@branch}."

      buffet = Buffet.new(Settings.get["repository"], true)
      buffet.run(@branch, {:skip_setup => @skip_setup, :dont_run_migrations => @dont_run_migrations})
    end

    def process_args
      ARGV.each do |arg|
        if arg == "--help"
          puts "Buffet command line interface"
          puts ""
          puts "Usage: bundle exec ruby lib/buffet/cli.rb [flags]"
          puts ""
          puts "Flags"
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
