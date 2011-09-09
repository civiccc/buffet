module Buffet
  class RemoteRunner
    def run
      #TODO: Should probably use a mutex here.
      if not @someone_running
        @someone_running = true

        buffet = Buffet.new(Settings.get["repository"], {:verbose => @verbose})
        buffet.run(@branch, {:skip_setup => false, :dont_run_migrations => false})
        return true
      end

      #return false
    end
  end
end
