require File.dirname(__FILE__) + '/../../spec_helper'

describe DemocracyInAction::API do
  before do
    @api = DemocracyInAction::API.new( *api_arguments )
  end

  it "knows when it is connected" do
    api = DemocracyInAction::API.new( *working_api_arguments )
    api.should be_connected
  end
  it "it is not connected by default" do
    api = DemocracyInAction::API.new 
    api.should_not be_connected
  end

  it "gets data from DIA" do
    unless @api.connected?
      my_http = stub_everything
      my_http.stub!(:===).and_return(true)
      my_http.stub!( :body ).and_return(File.read(File.dirname(__FILE__) + '/../../fixtures/supporter_by_limit_1.xml'))
      Net::HTTP.stub!(:new).and_return( my_http )
    end
    result = @api.get('supporter', :limit => 1).first
    result['key'].should match( /^\d+$/ )
    result['Email'].should_not be_nil
  end

  it "sends data to DIA for processing" do
    unless @api.connected?
      my_http = stub_everything
      my_http.stub!(:===).and_return(true)
      my_http.stub!( :body ).and_return(File.read(File.dirname(__FILE__) + '/../../fixtures/process.xml'))
      Net::HTTP.stub!(:new).and_return( my_http )
    end
    result = @api.process 'supporter', :Email => 'test3@radicaldesigns.org'
    result.should match( /^\d+$/ )
  end
end
