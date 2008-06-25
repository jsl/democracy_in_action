require File.dirname(__FILE__) + "/../../spec_helper"

describe DemocracyInAction::API do
  before do
    @api = DemocracyInAction::API.new( *api_arguments ) 
    #Net::HTTP::Post.stub!(:new).and_return(stub_everything)
  end
  describe "buildBody" do
    it "should convert key value pair into string" do
      body = @api.send(:buildBody, {"key" => "123456"})
      body.should == "key=123456"
    end
    it "should convert multiple key value pairs into string" do
      body = @api.send(:buildBody, {"key" => "123456", "email" => "test@domain.org"})
      body.should == "key=123456&email=test%40domain.org"
    end
    it "should convert key value pairs that contain arrays into string" do
      body = @api.send(:buildBody, {"key" => "123456", "names" => ["austin", "patrice", "seth"]})
      body.should == "names=austin&names=patrice&names=seth&key=123456"
    end
  end

  describe "disabling" do
    it "should provide ability to disable actually posting data to DIA" do
      DemocracyInAction::API.disable!
      DemocracyInAction::API.should be_disabled
    end
  end
end
