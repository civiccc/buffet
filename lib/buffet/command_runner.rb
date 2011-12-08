require 'logger'
require 'wopen3'

module Buffet
  class CommandRunner
    def initialize logger = Logger.new(STDOUT)
      @logger = logger
    end

    def run *command
      result = Wopen3.system *command
      @logger.info "\n" +
        "command: #{command.join ' '}\n" +
        "status: #{result.status}\n" +
        "stdout:\n#{result.stdout}\n" +
        "stderr:\n#{result.stderr}"
      result
    end
  end
end
