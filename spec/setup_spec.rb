require File.dirname(__FILE__) + "/spec_helper"

describe Buffet::Setup do
  include Rack::Test::Methods

  before(:all) do
    status = Buffet::StatusMessage.new
    @test_host = "bowler"
    @setup = Buffet::Setup.new "../working-directory", [@test_host], status, "unnecessary"
  end

  describe "#setup_db" do
    it "doesn't run setup db from this computer if settings.yml doesn't include this computer" do
      # Return a yaml file that doesn't include the current host.
      Buffet::Settings.stub!(:get).and_return do
        {"campfire"=>{"username"=>"escher", "room_name"=>"Operations", "subdomain"=>"causes", "password"=>"some_bogus_password"}, "repository"=>"git@github.com:causes/causes.git", "hosts"=>["chrisws"]} 
      end

      thread = Thread.new do 
        @setup.setup_db
      end

      sleep 100 #Give it time.
      `ps aux | grep setup_db | grep -v grep`.length.should == 0
      Thread.kill(thread)
    end
  end

  describe "#sync" do
   it "syncs convincingly" do
     #Force a small difference in the working directory.
     `touch working-directory/a`

     @setup.sync_hosts [@test_host]

     #Get the time modified of the working directory on the remote in HH:MM
     time_modified = `ssh buffet@#{@test_host} 'stat ~/#{Buffet::Settings.root_dir_name}/working-directory/a | grep Modify | cut -d" " -f3 | cut -d"." -f1 | cut -d":" -f1-2'`.chomp

     time_modified.should eql(Time.now.strftime("%H:%M"))
     `rm working-directory/a`
   end
  end
end

