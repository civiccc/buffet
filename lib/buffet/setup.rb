#!/usr/bin/env ruby

require 'ftools'
require 'benchmark'

require 'wopen3'
require 'buffet/master'
require 'buffet/campfire'
require 'buffet/status_message'
require 'memoize'
include Memoize

def expect_success(failure_msg)
  if $?.exitstatus != 0
    puts failure_msg
    puts diagnostic_output
    exit 1
  end
end

module Buffet
  class Setup

    # Initialize contains stuff that can be done preliminarily; that is, it's not
    # imperative that we have to be running a test in order to run this function. 
    # Right now, it just sets instance variables and clones the working directory
    # if it doesn't already exist.
    def initialize working_dir, hosts, status, repo
      @status = status
      @buffet_dir = File.expand_path(File.dirname(__FILE__) + "/../..")
      @working_dir = working_dir
      @hosts = hosts
      @progress = 0

      @repo = repo
    end

    # Install bundles on all remote machines.
    def bundle_install working_dir
      @hosts.each do |host|
        @status.set "Bundle install on #{host}"
        `ssh buffet@#{host} 'cd ~/buffet/#{working_dir}; bundle install --without production --path ~/buffet-gems' &`
      end
    end

    # Synchronize this directory to all hosts.
    def sync_hosts
      threads = []

      @status.set "Syncing #{@hosts.join(", ")}"

      @hosts.each do |host|
        threads << Thread.new do 
          `rsync -aqz --delete --exclude=tmp --exclude=log --exclude=doc --exclude=.git #{@buffet_dir} -e "ssh " buffet@#{host}:~/`
        end
      end

      threads.each do |thread|
        thread.join
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
        `bundle install --without production --path ~/buffet-gems`
        expect_success("Failed to bundle install on local machine.", output + errors)

        @status.set "Running db_setup\n"
        @status.increase_progress /^== [\d]+ /, 1120, "./../db_setup " + @hosts.join(" ")
        expect_success("Failed to db_setup on local machine.", output + errors)
      end
    end

    # Run the tests. There's lots of setup required before we can actaully run
    # them, including grabbing the latest version, installing gems, etc.
    def run(branch="master")
      remote = 'origin'

      update_working_dir remote, branch

      @status.set "Copying Buffet to hosts."
      sync_hosts

      @status.set "Running bundle install on hosts."
      bundle_install @working_dir
    end

    def get_failures
      if @master
        @master.get_failures_list
      else
        []
      end
    end
  end
end
