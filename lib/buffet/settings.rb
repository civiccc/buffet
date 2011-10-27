require 'yaml'
require 'fileutils'

module Buffet
  ROOT_DIR = File.expand_path('~/.buffet') 
  WORKING_DIR = File.expand_path('~/.buffet/working-directory')

  SETTINGS_FILE = File.expand_path('~/.buffet/settings.yml')
  LISTEN_PORT = "4567"

  # Singleton-style class that contains all Buffet-related settings and
  # constants.
  class Settings
    # Simple memoized wrapper around the settings yml file.
    def self.get
      @settings ||= YAML.load_file(SETTINGS_FILE)
    end

    def self.remove_host hostname
      self.get["hosts"].delete hostname
    end

    # Path to ~/.
    def self.home_dir
      ENV['HOME']
    end

    # The location of the Buffet settings file.
    def self.settings_file
      SETTINGS_FILE
    end

    # Location where buffet lives.
    def self.root_dir
      ROOT_DIR
    end

    # Name of directory where the cloned repository lives.
    def self.working_dir
      WORKING_DIR
    end

    # Name of the root directory.
    def self.root_dir_name
      # Currently, testing many repositories on the same computer at the same
      # time is deprecated. May bring this feature back some time in the future.
      ".buffet"
    end

    def self.list_branches
      Dir.chdir(Settings.working_dir) do
        `git branch -a`
      end
    end

    # Count the number of tests. Uses a heuristic.
    def num_tests
      # This is RSpec specific.
      `grep -r "  it" #{Settings.working_dir}/spec/ | wc`.to_i
    end

    # Name of this host.
    def self.hostname
      `uname -n`.split('.').first
    end

    def self.druby_listen_url host
      "druby://#{host}.:#{LISTEN_PORT}"
    end
  end

  LISTEN_URI = Settings.druby_listen_url Settings.hostname
end
