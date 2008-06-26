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
      @api.stub!(:send_request).and_return( fixture_file_read('supporter_by_limit_1.xml'))
    end

    result = @api.get(:table => 'supporter', 'limit' => 1).first
    result['key'].should match( /^\d+$/ )
    result['Email'].should_not be_nil
  end

  describe "the results returned from get" do
    before do
      @api.stub!(:send_request).and_return( fixture_file_read('supporter_by_limit_1.xml'))
      @result = @api.get('table' => 'supporter', 'limit' => 1).first
    end
    it "should have hash like access" do
      @result['First_Name'].should == 'test1'
    end
    it "should have method access" do
      @result.First_Name.should == 'test1'
    end
    it "should be enumerable" do
      @result.all?.should be_true
    end
  end

  it "sends data to DIA for processing" do
    unless @api.connected?
      @api.stub!(:send_request).and_return( fixture_file_read('process.xml'))
    end
    result = @api.process 'table' => 'supporter', :Email => 'test3@radicaldesigns.org'
    result.should match( /^\d+$/ )
  end

  describe "proxy" do
    it "specifies name of table in hash based on method called on api" do
      @api.should_receive(:get)
      @api.supporter.get
    end
    it "should call get with group" do
      group_proxy = @api.groups
      @api.should_receive(:get)
      @api.groups.get
    end
    it "should call the api process call when calling supporter.process" do
      @api.should_receive(:process)
      @api.supporter.process
    end

    it "should pass along the table name to the api" do
      @api.should_receive(:get).with(hash_including(:table => 'supporter'))
      @api.supporter.get
    end
  
    it "passes along odd methods to the API for handling" do
      @api.should_receive(:hot_topic)
      @api.supporter.hot_topic("Flex")
    end

    it "responds to columns and returns the correct number" do
      @api.stub!(:send_request).and_return(fixture_file_read('supporter_description.xml'))
      @api.supporter.columns.size.should == 56
    end
    it "describe returns the same thing as columns" do
      @api.stub!(:send_request).and_return(fixture_file_read('supporter_description.xml'))
      @api.supporter.describe.size.should == 56
    end

    it "counts the records in the table" do
      @api.stub!(:send_request).and_return(fixture_file_read('supporter_by_limit_1.xml'))
      @api.supporter.count.should == 11466 
    end
  end

  describe "count method" do
    it "counts the records in the table" do
      @api.stub!(:send_request).and_return(fixture_file_read('supporter_by_limit_1.xml'))
      @api.count(:table => 'supporter').should == 11466 
    end
  end

  describe "columns method" do
    it "should return a description of the given table" do
      @api.stub!(:send_request).and_return(fixture_file_read('supporter_description.xml'))
      @api.columns(:table => 'supporter').size.should == 56
    end
  end
end
