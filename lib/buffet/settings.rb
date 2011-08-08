require 'yaml'
require 'fileutils'

module Buffet
  GEM_DIR = File.expand_path(File.join(File.dirname(__FILE__) + '../../../'))
  ROOT_DIR = File.expand_path('~/.buffet') 
  WORKING_DIR = File.expand_path('~/.buffet/working-directory')

  SETTINGS_FILE = File.expand_path('~/.buffet/settings')
  SAMPLE_SETTINGS_FILE = File.expand_path('../../settings.sample.yml', File.join(File.dirname(__FILE__)))

  class Settings
    # Simple memoized wrapper around the settings yml file.
    def self.get
      while not File.exists? SETTINGS_FILE
        # Create ~/.buffet directory. Sync this directory to ~/.buffet.
        #
        # TODO: I only really need to move bin/buffet-worker and 
        # working-directory/ here; the rest is unnecessary. 
        FileUtils.mkdir_p WORKING_DIR
        FileUtils.cp_r GEM_DIR, File.expand_path("~/")
        FileUtils.mv File.expand_path("~/buffet"), File.expand_path("~/.buffet")
        FileUtils.cp SAMPLE_SETTINGS_FILE, SETTINGS_FILE

        # Launch user's favorite editor for first time configuration.
        editor = ENV["EDITOR"] || "vi"
        system "#{editor} #{SETTINGS_FILE}"
      end
      @settings ||= YAML.load_file(SETTINGS_FILE)
    end

    # Path to ~/.
    def self.home_dir
      ENV['HOME']
    end

    # The location of the Buffet settings file.
    def self.settings_file
      SETTINGS_FILE
    end

    # Name of directory where buffet lives.
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

    # Name of this host.
    def self.hostname
      `uname -n`.split('.').first
    end
  end
end
