require File.dirname(__FILE__) + "/../../spec_helper"

describe DemocracyInAction::API do
  before do
    @api = DemocracyInAction::API.new( *api_arguments )
  end
  it "should include password in url" do
    @api.
    raise @api.inspect
    @api.sendRequest('supporter', {"where" => {'Email' => 'test@test.org'}})
  end
end
