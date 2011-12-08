module Buffet
  class Slave
    attr_reader :user, :host

    def initialize user, host, project
      @user = user
      @host = host
      @project = project
    end

    def rsync src, dest
      Buffet.run! 'rsync', '-aqz', '--delete', '-e', 'ssh', src,
                  "#{user_at_host}:#{dest}"
    end

    def scp src, dest, options = {}
      args = [src, "#{user_at_host}:#{dest}"]
      args.unshift '-r' if options[:recurse]
      Buffet.run! 'scp', *args
    end

    def execute command
      Buffet.run! 'ssh', "#{user_at_host}",
                  "cd #{@project.directory_on_slave} && #{command}"
    end

    private

    def user_at_host
      "#{@user}@#{@host}"
    end
  end
end
