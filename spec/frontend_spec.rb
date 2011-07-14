require File.dirname(__FILE__) + "/spec_helper"

describe Buffet::Frontend do
  include Rack::Test::Methods

  describe "#failures" do
    before(:all) do
      get '/failures'
    end

    # You can't stub before :all.
    before(:each) do
      failures = app.runner.stub!(:get_failures).and_return do
        [ {:location => "Some Ruby File:76", :header => "This is a description of the bug.", :backtrace => "This is a really\n really\n  really\n long backtrace full of 99% useless info."},
          {:location => "Some Ruby File:22", :header => "Something Bad happened.", :backtrace => "This backtrace is comparatively short."}]
      end
    end

    it "does not error when returning failures" do
      get '/failures'
      last_response.should be_ok
    end

   it "contains convincing output for /failures" do
      get '/failures'

     ["Something Bad happened", "Some Ruby File"].each do |string|
       last_response.body.should include(string)
     end
   end
  end
end

