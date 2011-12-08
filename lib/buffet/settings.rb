require 'yaml'

module Buffet
  SETTINGS_FILE = 'buffet.yml'

  class Settings
    def self.[](name)
      @settings ||= YAML.load_file(SETTINGS_FILE)
      @settings[name]
    end

    def self.slaves
      @slaves ||= self['slaves'].map do |slave_hash|
        Slave.new slave_hash['user'], slave_hash['host'], project
      end
    end

    def self.project
      @project ||= begin
        project = self['project']
        Project.new(project['name'], project['directory'])
      end
    end

    def self.framework
      self['framework'].upcase || 'RSPEC1'
    end

    def self.prepare_script
      self['prepare_script'] || 'bin/before-buffet-run'
    end
  end
end
