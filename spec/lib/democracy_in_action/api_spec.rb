require File.dirname(__FILE__) + '/../../spec_helper'

describe DemocracyInAction::API do
  before do
    @api = DemocracyInAction::API.new( api_arguments )
  end

  it "knows when it is connected" do
    api = DemocracyInAction::API.new( working_api_arguments )
    api.should be_connected
  end
  it "it is not connected when passed bad arguments" do
    api = DemocracyInAction::API.new( api_arguments )
    api.should_not be_connected
  end

  describe "initialize" do
    it "should raise an error if username, password, orgkey, or domain is not specified" do
      lambda{DemocracyInAction::API.new({})}.should raise_error
    end
    api_arguments.each do |key, value| 
      it "sets attribute #{key} to equal the passed value" do
        @api.send(key).should == value
      end
    end

    it "assigns urls based on the passed domain" do
      @api = DemocracyInAction::API.new( api_arguments ) 
      @api.urls.should == DemocracyInAction::API::DOMAINS[api_arguments[:domain]]
    end

    it "raises an error if an unsupported domain is passed" do
      lambda {DemocracyInAction::API.new( api_arguments.merge({ :domain => :joe }) ) }.should raise_error
    end

    describe "accepts custom urls in place of a domain" do
      before do
        @args = api_arguments.dup
        @args.delete(:domain)
      end
      it "raises an error if the urls are bad" do
        lambda {DemocracyInAction::API.new( @args.merge({ :urls => { :joe => 'bears' }}) ) }.should raise_error( DemocracyInAction::ConnectionInvalid )
      end
      it "raises no error if all required urls are given" do
        lambda {DemocracyInAction::API.new( @args.merge({ :urls => { :get => 'cares', :process => 'bears', :delete => 'cubs' }}) ) }.should_not raise_error( DemocracyInAction::ConnectionInvalid )
      end
    end

  end

  it "gets data from DIA" do
    unless @api.connected?
      @api.stub!(:sendRequest).and_return( fixture_file_read('supporter_by_limit_1.xml'))
    end

    result = @api.get('supporter', 'limit' => 1).first
    result['key'].should match( /^\d+$/ )
    result['Email'].should_not be_nil
  end

  it "sends data to DIA for processing" do
    unless @api.connected?
      @api.stub!(:sendRequest).and_return( fixture_file_read('process.xml'))
    end
    result = @api.process 'supporter', :Email => 'test3@radicaldesigns.org'
    result.should match( /^\d+$/ )
  end
end
