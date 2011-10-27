require File.dirname(__FILE__) + "/spec_helper"

describe Buffet::Setup do
  include Rack::Test::Methods

  before(:all) do
    status = Buffet::StatusMessage.new
    @test_host = Buffet::Settings.get["hosts"].first
    @setup = Buffet::Setup.new(Buffet::Settings.root_dir + "/working-directory", [@test_host], status, "unnecessary")
  end

  describe "#db_setup" do
    it "doesn't run setup db from this computer if settings.yml doesn't include this computer" do
      # Return a yaml file that doesn't include the current host.
      Buffet::Settings.stub!(:get).and_return do
        {"repository"=>"git@github.com:causes/causes.git", "hosts"=>["chrisws"]}
      end

      thread = Thread.new do 
        @setup.db_setup
      end

      sleep 0.1 #Give it time.

      `ps aux | grep db_setup | grep -v grep`.length.should == 0
      Thread.kill(thread)# The entire db_setup script takes forever, so kill it.

      # db_setup will have changed the current dir, but since we killed it, it's
      # possible that it wasn't able to change it back.
      Dir.chdir(Buffet::Settings.root_dir)
    end
  end

  describe "#sync" do
   it "syncs convincingly" do
     #Force a small difference in the working directory.
     `touch #{Buffet::Settings.working_dir}/a`

     @setup.sync_hosts [@test_host]

     #Get the time modified of the working directory on the remote in HH:MM
     time_modified = `ssh buffet@#{@test_host} 'stat ~/#{Buffet::Settings.root_dir_name}/working-directory/a | grep Modify | cut -d" " -f3 | cut -d"." -f1 | cut -d":" -f1-2'`.chomp

     time_modified.should eql(Time.now.strftime("%H:%M"))
     `rm working-directory/a`
   end
  end
end

