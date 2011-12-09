module Buffet
  class Project
    attr_reader :name, :directory

    def initialize directory
      @name = File.basename directory
      @directory = File.expand_path directory
    end

    def directory_on_slave
      "#{Buffet.workspace_dir}/#{name}"
    end

    def support_dir_on_slave
      "#{directory_on_slave}/.buffet"
    end

    def sync_to slave
      slave.execute "mkdir -p #{directory_on_slave}"
      slave.rsync directory + '/', directory_on_slave
    end
  end
end
