require 'yaml'

module Buffet
  class Settings
    DEFAULT_SETTINGS_FILE       = 'buffet.yml'
    DEFAULT_PREPARE_SCRIPT      = 'bin/before-buffet-run'
    DEFAULT_EXCLUDE_FILTER_FILE = '.buffet-exclude-filter'

    class << self
      def settings_file=(settings_file)
        @settings_file = settings_file
        reset!
      end

      def settings_file
        @settings_file || DEFAULT_SETTINGS_FILE
      end

      def [](name)
        @settings ||= load_file(settings_file)
        @settings[name]
      end

      def slaves
        @slaves ||= self['slaves'].map do |slave_hash|
          Slave.new slave_hash['user'], slave_hash['host'], project
        end
      end

      def worker_command
        self['worker_command'] || '.buffet/buffet-worker'
      end

      def project_name=(project_name)
        project.name = project_name
      end

      def project
        @project ||= Project.new Dir.pwd
      end

      def framework
        self['framework'].upcase || 'RSPEC1'
      end

      def prepare_script
        self['prepare_script'] || DEFAULT_PREPARE_SCRIPT
      end

      def has_prepare_script?
        self['prepare_script'] || File.exist?(DEFAULT_PREPARE_SCRIPT)
      end

      def exclude_filter_file
        self['exclude_filter_file'] || DEFAULT_EXCLUDE_FILTER_FILE
      end

      def has_exclude_filter_file?
        self['exclude_filter_file'] || File.exist?(DEFAULT_EXCLUDE_FILTER_FILE)
      end

      def reset!
        @settings = nil
      end

    private

      def load_file file
        @settings = YAML.load_file file
      end
    end
  end
end
