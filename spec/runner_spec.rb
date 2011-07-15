require File.dirname(__FILE__) + "/spec_helper"

describe Buffet::Runner do
  include Rack::Test::Methods

  before(:all) do
    @test_host = "bowler"
    @runner = Buffet::Runner.new
  end

  before(:each) do
    @runner.stub!(:hosts).and_return { [@test_host] }
  end

  describe "#sync" do
   it "syncs convincingly" do
     #Force a small difference in the working directory.
     `touch working-directory/a`

     @runner.sync_hosts

     #Get the time modified of the working directory on the remote in HH:MM
     time_modified = `ssh buffet@#{@test_host} 'stat ~/buffet/working-directory/ | grep Modify | cut -d" " -f3 | cut -d"." -f1 | cut -d":" -f1-2'`.chomp

     time_modified.should eql(Time.now.strftime("%H:%M"))
     `rm working-directory/a`
   end
  end
end

