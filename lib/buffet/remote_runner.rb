$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/.."))

module Buffet

  # RemoteRunner allows users to run Buffet remotely. You can start this
  # process by running Buffet with --listen, and you can run it remotely with
  # buffet-remote [hostname].
  class RemoteRunner
    def initialize
      @lock = Mutex.new
      @someone_running = false
    end

    def can_run?
      return !@someone_running
    end

    def lock_with_info
      @lock.synchronize do
        @someone_running = true
        yield

        @someone_running = false
      end
    end
    
    # There's a potential race condition here where if smoeone checks can_run?,
    # determines it to be true, and then someone else races in and calls run
    # first, the first guy will be waiting for ages before Buffet starts and
    # won't know what's going on. The chances of this happening seem pretty
    # small.
    def run
      lock_with_info do
        buffet = Buffet.new(Settings.get["repository"], {:verbose => @verbose})
        buffet.run(@branch, {:skip_setup => false, :dont_run_migrations => false})
      end
    end
  end
end
