require 'logger'
require 'wopen3'

module Buffet
  class CommandRunner
    def initialize logger = Logger.new(STDOUT)
      @logger = logger
    end

    def run *command
      start_time = Time.now
      result = Wopen3.system *command
      end_time = Time.now
      @logger.info "\n" +
        "command: #{command.join ' '}\n" +
        "time: #{end_time - start_time}\n" +
        "status: #{result.status}\n" +
        "stdout:\n#{result.stdout}\n" +
        "stderr:\n#{result.stderr}"
      result
    end
  end
end
