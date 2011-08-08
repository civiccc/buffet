#!/usr/bin/env ruby

require 'ftools'
require 'benchmark'
require 'net/ssh'

require 'memoize'
require 'wopen3'

require 'buffet/master'
require 'buffet/campfire'
require 'buffet/status_message'

include Memoize
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

      clone_repo
    end

    # Clone the repository into the working directory, if necessary. Will happen
    # if the dir is nonexistent or a clone of the wrong repository.
    def clone_repo
      # TODO: This is a sloppy way to get the remote. Move towards using a ruby
      # git wrapper. 
      remote = `cd #{Settings.working_dir} && git remote -v | grep "(fetch)" | head -1 | cut -f2 | cut -d" " -f1`.chomp

      return if remote == Settings.get["repository"]
      puts "About to delete #{Settings.working_dir}, and replace it with a new clone. Continue? (y/n)"
      exit 0 unless gets.chomp == "y"

      FileUtils.rm_rf Settings.working_dir if File.directory? Settings.working_dir

      @status.set "Cloning #{@repo}. This will only happen once.\n"

      `git clone #{@repo} #{Settings.working_dir}`
    end


    # Synchronize this directory (the buffet directory) to all hosts.
    def sync_hosts hosts
      threads = []

      @status.set "Updating #{hosts.join(", ")}"

      hosts.each do |host|
        threads << Thread.new do 
          # Sync all of Buffet.
          # TODO: The .git repository needs to be synced once, and only once.
          `rsync -aqz --delete --exclude=tmp --exclude=.bundle --exclude=log --exclude=doc #{Settings.root_dir} -e "ssh " buffet@#{host}:~/`

          # Run bundle install if necessary.
          `ssh buffet@#{host} 'cd ~/#{Settings.root_dir_name}/working-directory && bundle check > /dev/null; if (($? != 0)); then bundle install --without production --path ~/buffet-gems; fi'`
        end
      end

      threads.each do |thread|
        thread.join
      end
    end

    def setup_db
      Dir.chdir(@working_dir) do
        @status.set "Running db_setup\n"

        if Settings.get['hosts'].include? Settings.hostname
          @status.increase_progress /^== [\d]+ /, 1120, Settings.root_dir + "/db_setup " + @hosts.join(" ")
        else
          # We don't want to execute db_setup on current machine, since it's not in the hosts.
          # Copy db_setup to an arbitrary host we're allowed to use.
          #
          # This is primarily useful for developing Buffet, since we want to be 
          # able to run Buffet from the same computer we run tests on, but we 
          # don't want to have conflicts on the database.

          new_setup_host = "buffet@#{@hosts.first}"
          new_setup_location = "~/#{Settings.root_dir_name}/working-directory"

          `scp #{Settings.root_dir}/db_setup #{new_setup_host}:#{new_setup_location}/db_setup`
          command = "ssh #{new_setup_host} \"cd #{new_setup_location}; ./db_setup " + @hosts.join(" ") + "\""
          puts command
          
          Net::SSH.start(@hosts.first, 'buffet') do |ssh|
            channel = ssh.open_channel do |ch|
              ch.exec "cd #{new_setup_location}; ./db_setup " + @hosts.join(" ") do |ch, success|
                ch.on_data do |c, data|
                  puts data
                end
                # can also capture on_extended_data for stderr
              end
            end

            channel.wait
          end
        end
        expect_success("Failed to db_setup on local machine.")
      end
    end

    def update_local_dir remote, branch
      Dir.chdir(@working_dir) do
        `git fetch #{remote}`

        rev = `git rev-parse #{remote}/#{branch}`.chomp # Get hash
        if $?.exitstatus != 0
          # probably got passed a SHA-1 hash instead of a branch name
          rev = `git rev-parse #{branch}`.chomp
        end
        expect_success('Rev-parse failed')

        @status.set "Updating local repository.\n"
        @status.increase_progress(/a/, 30,
                     "git checkout #{rev} &&
                      git reset --hard #{rev} &&
                      git clean -f &&
                      git submodule update --init &&
                      git submodule foreach git reset --hard HEAD &&
                      git submodule foreach git clean -f".gsub(/\n/, ''))
        expect_success("Failed to clone local repository.")
        ENV['RAILS_ENV'] = 'test'

        @status.set "Updating local gems.\n"
        `bundle install --without production --path ~/buffet-gems`
        expect_success("Failed to bundle install on local machine.")
      end
    end

    # Run the tests. There's lots of setup required before we can actaully run
    # them, including grabbing the latest version, installing gems, etc.
    def run(dont_run_migrations, branch="master")
      remote = 'origin'

      update_local_dir remote, branch

      @status.set "Copying Buffet to hosts."
      sync_hosts @hosts

      @status.set "Running bundle install on hosts."

      setup_db unless dont_run_migrations or (not File.exists?(Settings.root_dir + "/setup_db"))
    end

    def get_failures
      if @master
        @master.get_failures_list
      else
        []
      end
    end

    private

    #TODO: Take diagnostic output also.
    def expect_success(failure_msg)
      if $?.exitstatus != 0
        puts failure_msg
        exit 1
      end
    end
  end
end
