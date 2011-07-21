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
      @branch = "master"
      @skip_setup = false

      process_args

      puts "Running Buffet on branch #{@branch}." #TODO: I'm actually not...

      buffet = Buffet.new(Settings.get["repository"], true)
      buffet.run @skip_setup
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
          puts "\t--branch=some_branch" #TODO
          puts "\t\tRun tests on branch some_branch."
          puts ""
          puts "\t--quiet" #TODO
          puts "\t\tDon't output anything while testing, except ./F."

          exit 0
        elsif arg == "--skip-setup"
          @skip_setup = true
        end
      end
    end
  end

  CLI.new
end
