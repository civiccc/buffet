require File.dirname(__FILE__) + "/spec_helper"

describe Buffet::Setup do
  include Rack::Test::Methods

  before(:all) do
    status = Buffet::StatusMessage.new
    @test_host = "bowler"
    @setup = Buffet::Setup.new "../working-directory", [@test_host], status, "unnecessary"
  end

  describe "#sync" do
   it "syncs convincingly" do
     #Force a small difference in the working directory.
     `touch working-directory/a`

     @setup.sync_hosts [@test_host]

     #Get the time modified of the working directory on the remote in HH:MM
     time_modified = `ssh buffet@#{@test_host} 'stat ~/#{Buffet::Settings.root_dir}/working-directory/a | grep Modify | cut -d" " -f3 | cut -d"." -f1 | cut -d":" -f1-2'`.chomp

     time_modified.should eql(Time.now.strftime("%H:%M"))
     `rm working-directory/a`
   end
  end
end

