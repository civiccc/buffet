require 'yaml'

module Buffet
  SETTINGS_FILE = File.expand_path('~/.buffet')
  SAMPLE_SETTINGS_FILE = File.expand_path('../../settings.sample.yml', File.join(File.dirname(__FILE__)))

  class Settings
    # Simple memoized wrapper around the settings yml file.
    def self.get
      while not File.exists? SETTINGS_FILE
        `cp #{SAMPLE_SETTINGS_FILE} #{SETTINGS_FILE}`

        editor = ENV["EDITOR"] || "vi"
        system "#{editor} #{SETTINGS_FILE}"

      end
      @settings ||= YAML.load_file(SETTINGS_FILE)
    end

    def self.home_dir
      `echo ~`.chomp
    end

    def self.root_dir
      File.expand_path(__FILE__ + "../../../../")
    end

    def self.working_dir
      File.expand_path(__FILE__ + "../../../../working-directory")
    end

    def self.root_dir_name
      File.expand_path(__FILE__ + "../../../../").split("/").last
    end

    def self.hostname
      `uname -n`.split('.').first
    end
  end
end
