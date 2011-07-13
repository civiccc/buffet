require 'sinatra'
require 'erb'
require File.expand_path('buffet', File.join(File.dirname(__FILE__)))

module Buffet
  # The Buffet Sinatra web server provides a simple frontend to Buffet. The most
  # important parts are /test, which is the central link to run Buffet, and
  # /start-buffet-server/BRANCH-NAME, which will start buffet on the specified
  # branch if it isn't already running. (In short, test is for browsers,
  # start-buffet-server is for terminals.)
  class Frontend < Sinatra::Base

    $buffet_server = Buffet::Runner.new
    $testing_mode = false

    # There is a bug in Sinatra where if you surreptitiously chdir somewhere then
    # the directory paths get all confused. As a workaround, we set the paths
    # manually.
    set :views, File.expand_path(File.join(File.dirname(__FILE__), 'views'))
    set :public, File.expand_path(File.join(File.dirname(__FILE__), 'public'))


    # Going to hope that no one tries to exploit Buffet by writing a test script
    # that contains JS inside of it. If that happens, you have bigger problems than
    # a broken test framework.
    class String
      def sanitize
        self.gsub("<", "&lt;").gsub(">", "&gt;")
      end
    end

    # Render the main page.
    get '/test' do
      # Branches is originally a newline delimited list. Turn it into a JS array.
      # Also parse out the /remotes/origin/ part which isn't helpful.
      #
      @branches = '["' +
        $buffet_server.list_branches.
          split("\n").
          map {|branch| branch[2 + "remotes/origin/".length .. branch.length]}.
          reject {|branch| branch == nil or branch.include? '->'}.
          join('", "') + '"]'

      erb :index
    end

    # Render some sample data
    get '/test-css' do
      $testing_mode = true
      @branches = '["one", "two", "three"]'

      erb :index
    end

    # Runs buffet on branch given. (More explicitly, navigate or curl to
    # /start-buffet-server/the_original_gangsta to run tests on that branch.)
    get '/start-buffet-server/:branch' do
      branch = params[:branch]

      if not $buffet_server.running?
        Thread.new do
          $buffet_server.run
        end
        "Server started"
      else
        "Server already running"
      end
    end

    get '/is-running' do
      $buffet_server.running?.to_s
    end

    # Returns status of pre-testing setup.
    get '/stats' do
      if $testing_mode
        return "Tests run: <b>256 (23%)</b> Failures: <b>2</b>"
      end
      $buffet_server.get_status.gsub("\n", "<br>")
    end

    get '/title' do
      if $buffet_server.running?
        "Reserved for #{$buffet_server.get_repo.gsub(/git@github.com:(.*)\.git/, "\\1")}, party of #{$buffet_server.num_tests}."
      else
        "Open for reservations"
      end
    end

    # Returns all failures in nicely formatted HTML.
    # (The massive concentration of fail in this function makes me laugh.)
    get '/failures' do
      failures = $buffet_server.get_failures

      if $testing_mode
        failures = [ {:location => "Some Ruby File:76", :header => "This is a description of the bug.", :backtrace => "This is a really\n really\n  really\n long backtrace full of 99% useless info."},
                     {:location => "Some Ruby File:22", :header => "Something Bad happened.", :backtrace => "This backtrace is comparatively short."}]
      end

      fail_html = ""

      failures.each_with_index do |fail, index|
        fail_html += "<div class='fail'>"
        fail_html += "<div class='fail-location' id='fail-#{index}-location'> #{fail[:location]} </div>"
        fail_html += "<div class='fail-header' id='fail-#{index}-location'> #{fail[:header]} </div>"
        # The order of functions (sanitize, then gsub) is important, because
        # otherwise all the <br>s would be rendered as text, which is not what we
        # want at all.
        fail_html += "<div class='fail-backtrace' id='fail-#{index}-location'> #{fail[:backtrace].sanitize.gsub("\n", "<br>")} </div>"
        fail_html += "</div>"
      end

      if fail_html == ""
        if $buffet_server.running?
          #TODO: Don't show this when we haven't even started running tests.
          "<div class='you-are-a-winner'>All tests pass! ...so far.</div>"
        else
          ""
        end
      else
        fail_html
      end
    end
  end
end
