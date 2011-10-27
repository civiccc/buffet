$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))

# No, Buffet does not use Buffet to run its own test cases. That would be silly.

require 'sinatra'
require 'rack/test'

require 'buffet/frontend'
require 'buffet/settings'

set :environment, :test

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
end

def app
  Buffet::Frontend
end

