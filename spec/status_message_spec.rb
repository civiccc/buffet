require File.dirname(__FILE__) + "/spec_helper"

describe Buffet::StatusMessage do
  before(:all) do
    @message = Buffet::StatusMessage.new
  end

  it "has a message" do
    @message.set "What's up?"

    @message.to_s.should == "What's up?"
  end

  it "should increase progress on a trivial command" do
    @message.set "Three a's"
    @message.increase_progress /a/, 3, "echo a && echo a && echo a"
    
    @message.to_s.should == "Three a's (3 of 3)"
  end

  it "should not break &&s inside anything" do
    @message.set "Three a's"
    @message.increase_progress /a/, 3, "ssh buffet@jeffws 'echo a && echo a && echo a'"
    
    @message.to_s.should == "Three a's (3 of 3)"
  end

  it "turns into a string when needed" do
    @message.set "Test"
    @message.to_s.should == "Test"
  end

  it "has extra methods when set() with a hash" do
    @message.set({:a => "YUP", :bbb => "herp"})

    @message.a.should == "YUP"
    @message.bbb.should == "herp"
  end
end

