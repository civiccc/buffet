require 'yaml'

module Buffet
  SETTINGS_FILE = File.expand_path('settings.yml', File.join(File.dirname(__FILE__)))

  def self.settings
    @settings ||= YAML.load_file(SETTINGS_FILE)
  end
end
