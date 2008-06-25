require File.dirname(__FILE__) + "/../../spec_helper"

describe "DIA Service" do
  before do
    @api = DemocracyInAction::API.new( working_api_arguments ) 
  end
  it "should accept key value pairs that contain arrays in the body of the request post" do
    pending
    body = @api.send(:buildBody, {"key" => "123456", "names" => ["austin", "patrice", "seth"]})
    body.should == "names=austin&names=patrice&names=seth&key=123456"
  end
end
