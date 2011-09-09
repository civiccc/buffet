$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/.."))

module Buffet
  class RemoteRunner
    def initialize
      @lock = Mutex.new
    end

    def run
      @lock.synchronize do
        @someone_running = true

        buffet = Buffet.new(Settings.get["repository"], {:verbose => @verbose})
        buffet.run(@branch, {:skip_setup => false, :dont_run_migrations => false})
        return true
      end

      return false
    end
  end
end
