require 'wopen3'

module Buffet
  # Maintains a status message, along with an optional progress amount
  # (which is generically displayed as (x of y), for example (5 of 100).
  # The progress amount gets reset when you set a new message.
  class StatusMessage
    def initialize(should_display=false)
      @message = ""
      @show_progress = false
      @progress = 0
      @max_progress = 0
      @should_display = should_display
    end

    # Set the status message. Support for either setting it to a string or a 
    # hash. If it's a string, StatusMessage mimics a string; similarly with 
    # hashes.
    def set(message, hide=false)
      @message = message
      @show_progress = false

      display if not hide
    end

    # Convenience method. This makes things like puts status work.
    def to_s
      if @show_progress
        "#{@message} (#{@progress} of #{@max_progress})"
      else
        "#{@message}"
      end
    end

    # Run the command COMMAND, and every time an output line matches PROGRESS_REGEX,
    # add to self
    def increase_progress(progress_regex, expected, command)
      start_progress(expected)
      # It's necessary to split along && because passing in multiple commands to
      # popen3 does not appear to work.
      command.split('&&').map do |command|
        Wopen3.popen3(*command.split(" ")) do |stdin, stdout, stderr|
          threads = []
          threads << Thread.new(stdout) do |out|
            out.each do |line|
              if progress_regex =~ line
                add_to_progress
              end
            end
          end

          threads << Thread.new(stderr) do |err|
            err.each do |line|
              puts "ERR: #{line}"
            end
          end

          threads.each do |thread|
            thread.join
          end
        end
      end

      if $?.exitstatus != 0
        set "Command #{command} failed."
      end
    end

    # If someone has set() the status to a hash, you can get the values out
    # by doing status.keyword_in_hash
    def method_missing(method_sym, *args, &block)
      @message[method_sym]
    end

    private 

    # The progress messages are for showing (x of y) on commands that take
    # long enough for users to feel antsy while watching them. The counter
    # is incremented every time a regex is matched on the output of the command.
    def start_progress(max_progress)
      @show_progress = true
      @max_progress = max_progress
      @progress = 0
      display
    end

    def add_to_progress
      @progress += 1
      display
    end

    def display
      puts(to_s) if @should_display
    end
  end
end
