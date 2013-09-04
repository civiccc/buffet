require 'yaml'

module Buffet
  class Settings
    DEFAULT_LOG_FILE            = 'buffet.log'
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

      def allowed_slave_prepare_failures
        self['allowed_slave_prepare_failures'] || 0
      end

      def worker_command
        self['worker_command'] || '.buffet/buffet-worker'
      end

      def log_file=(log)
        @log_file = log
      end

      def log_file
        @log_file || self['log_file'] || DEFAULT_LOG_FILE
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

      def failure_threshold
        self['failure_threshold'] || 2
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
