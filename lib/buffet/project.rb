module Buffet
  class Project
    PROJECTS_DIR = '.buffet/projects'

    attr_reader :name, :directory

    def initialize name, directory
      @name = name
      @directory = File.expand_path directory
    end

    def directory_on_slave
      # TODO: Change based on which user is running
      "#{PROJECTS_DIR}/#{name}" # Relative to home directory
    end

    def support_dir_on_slave
      "#{directory_on_slave}/.buffet"
    end

    def sync_to slave
      slave.rsync directory, PROJECTS_DIR
    end
  end
end
