require File.dirname(__FILE__) + "/spec_helper"

describe Buffet::StatusMessage do
  before(:all) do
    @message = Buffet::StatusMessage.new
  end

  it "has a message" do
    @message.set "What's up?"

    @message.get.should eql("What's up?")
  end

  it "should increase progress on a trivial command" do
    @message.set "Three a's"
    @message.increase_progress /a/, 3, "echo a && echo a && echo a"
    
    @message.get.should eql("Three a's (3 of 3)")
  end
end

