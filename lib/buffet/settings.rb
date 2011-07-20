require 'yaml'

module Buffet
  SETTINGS_FILE = File.expand_path('../../settings.yml', File.join(File.dirname(__FILE__)))

  class Settings
    # Simple memoized wrapper around the settings yml file.
    def self.get
      @settings ||= YAML.load_file(SETTINGS_FILE)
    end

    def self.root_dir
      File.expand_path(__FILE__ + "../../../../").split("/").last
    end
  end
end
