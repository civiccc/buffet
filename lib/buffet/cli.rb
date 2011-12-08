#!/usr/local/bin/ruby
$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/.."))

require 'buffet'
require 'optparse'

module Buffet
  class CLI
    def initialize args
      opts = OptionParser.new do |opts|
        opts.banner = "Usage: buffet [options] [spec-files]"
      end.parse!(args)

      specs = Buffet.extract_specs_from(opts.empty? ? 'spec' : opts)
      Runner.new.run specs
    end
  end
end
