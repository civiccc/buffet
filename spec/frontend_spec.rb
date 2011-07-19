require File.dirname(__FILE__) + "/spec_helper"

describe Buffet::Frontend do
  include Rack::Test::Methods

  describe "sanitize" do
    it "properly sanitizes simple HTML" do
      app.sanitize("<br>").should_not include("<")
      app.sanitize("<br>").should_not include(">")
    end
  end

  describe "#failures" do
    # You can't stub before :all.
    before(:each) do
      failures = app.runner.stub!(:get_failures).and_return do
        [ {:location => "Some Ruby File:76", :header => "This is a description of the bug.", :backtrace => "This is a really\n really\n  really\n long backtrace full of 99% useless info."},
          {:location => "Some Ruby File:22", :header => "Something Bad happened.", :backtrace => "This backtrace is comparatively short, but has some <div> html <br> elements <blink> <marquee>."}]
      end
    end

    it "returns failures without error" do
      get '/failures'
      last_response.should be_ok
    end

    it "sanitizes backtraces" do
      get '/failures'

      last_response.body.should_not include("<blink>")
      last_response.body.should_not include("<marquee>")
    end

    it "contains convincing output for /failures" do
      get '/failures'

     ["Something Bad happened", "Some Ruby File"].each do |string|
       last_response.body.should include(string)
     end
    end
  end

  describe "#failures, before any failures" do
    it "should not report that all tests pass before any tests have been tested" do
      get "/failures"

      puts last_response.body
      last_response.body.should_not include("All tests pass!")

      app.runner.stub!(:running?).and_return { true }

      get "/failures"

      puts last_response.body
      last_response.body.should_not include("All tests pass!")
    end
  end

  describe "#titles" do
    it "indicates that no one is running tests (and does so in a cute way)" do
      app.runner.stub!(:running?).and_return { false }
      get '/title'
      
      last_response.body.should include("Open")
    end

    it "indicates that tests are being run" do
      app.runner.stub!(:running?).and_return { true }
      get '/title'

      last_response.body.should include("Reserved")
    end

    it "shows that a nonzero number of tests are being run" do
      app.runner.stub!(:running?).and_return { true }
      get '/title'
      
      last_response.body.should_not include "party of 0"
    end
  end

  describe "#stats" do
    it "should return something" do
      get "/stats"

      last_response.should be_ok
    end
  end
end
