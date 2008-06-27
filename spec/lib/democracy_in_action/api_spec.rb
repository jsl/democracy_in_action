require File.dirname(__FILE__) + '/../../spec_helper'

describe DemocracyInAction::API do
  before do
    @api = DemocracyInAction::API.new( api_arguments )
  end

  describe "authentication" do
    describe "with invalid credentials" do
      before do
        @api.stub!(:authentication_failed?).and_return(false)
        @response = @api.authenticate
      end
      it "should return 302" do
        @response.code.should == "302"
      end
      it "should have an empty body" do
        @response.body.should be_empty
      end
      it "should redirect to login" do
        @response['location'].should =~ /login.jsp/
      end
      it "should set cookie expires to the beginning of time" do
        cookies = @response['set-cookie'].split('; ')
        cookies.detect {|c| c =~ /Expires=Thu, 01-Jan-1970/}.should_not be_nil
      end
    end
    describe "with valid credentials" do
      before do
        @api = DemocracyInAction::API.new( working_api_arguments )
        @response = @api.authenticate
      end
      it "should return 302" do
        @response.code.should == "302"
      end
      it "should have an empty body" do
        @response.body.should be_empty
      end
      #NOTE: this is the only difference between success and failure
      it "should not redirect to login" do
        @response['location'].should_not =~ /login/
      end
      it "should redirect to hq" do
        @response['location'].should =~ /hq/
      end
      it "should set cookie expires to the beginning of time" do
        cookies = @response['set-cookie'].split('; ')
        cookies.detect {|c| c =~ /Expires=Thu, 01-Jan-1970/}.should_not be_nil
      end
    end
  end

  describe "responses" do
    before do
      @unauthed = DemocracyInAction::API.new( api_arguments )
      @unauthed.stub!(:authentication_failed?).and_return(false)
      @unauthed.authenticate

      @authed = DemocracyInAction::API.new( working_api_arguments )
      @authed.authenticate
      @orgkey = 74
    end

    describe "getObject" do
      describe "when not authenticated" do
        it "should set a cookie" do
          r = @unauthed.make_https_request('https://sandbox.democracyinaction.org/api/getObject.sjs?object=supporter&key=-1')
          r['set-cookie'].should_not be_nil
        end
        it "should have organization_KEY undefined" do
          r = @unauthed.make_https_request('https://sandbox.democracyinaction.org/api/getObject.sjs?object=supporter&key=-1')
          r.body.should =~ /<data organization_KEY="undefined">/
        end
      end
      describe "when authenticated" do
        it "should not set a cookie" do
          r = @authed.make_https_request('https://sandbox.democracyinaction.org/api/getObject.sjs?object=supporter&key=-1')
          r['set-cookie'].should be_nil
        end
        it "should ALSO have organization_KEY undefined if we don't have access" do
          r = @api.make_https_request('https://sandbox.democracyinaction.org/api/getObject.sjs?object=supporter&key=-1')
          r.body.should =~ /<data organization_KEY="undefined">/
        end
      end
    end

    describe "getObjects" do
      describe "when not authenticated" do
        it "should have organization_KEY == -1" do
          r = @unauthed.make_https_request('https://sandbox.democracyinaction.org/api/getObjects.sjs?object=supporter&limit=0')
          r.body.should =~ /<data organization_KEY="-1">/
        end
        it "should set a cookie" do
          r = @unauthed.make_https_request('https://sandbox.democracyinaction.org/api/getObjects.sjs?object=supporter&limit=0')
          r['set-cookie'].should_not be_nil
        end
      end
      describe "when authenticated" do
        it "should have organization_KEY == your organization key" do
          r = @authed.make_https_request('https://sandbox.democracyinaction.org/api/getObjects.sjs?object=supporter&limit=0')
          r.body.should =~ /<data organization_KEY="#{@orgkey}">/
        end
        it "should NOT set a cookie" do
          r = @authed.make_https_request('https://sandbox.democracyinaction.org/api/getObjects.sjs?object=supporter&limit=0')
          r['set-cookie'].should be_nil
        end
      end
    end

    describe "save" do
      describe "when not authenticated" do
        it "should have error message" do
          r = @unauthed.make_https_request('https://sandbox.democracyinaction.org/save?xml&object=supporter&Email=rd_test@email.com')
          r.body.should =~ /<error object="supporter"/ 
        end
        it "should not set org token cookie" do
          r = @unauthed.make_https_request('https://sandbox.democracyinaction.org/save?xml&object=supporter&Email=rd_test@email.com')
          r['set-cookie'].should_not =~ /org\d+token/ 
        end
        it "should set a session cookie" do
          r = @unauthed.make_https_request('https://sandbox.democracyinaction.org/save?xml&object=supporter&Email=rd_test@email.com')
          r['set-cookie'].should_not be_nil
        end
      end
      describe "when authenticated" do
        it "should have a success message" do
          r = @authed.make_https_request('https://sandbox.democracyinaction.org/save?xml&object=supporter&Email=rd_test@email.com')
          r.body.should =~ /<success object="supporter"/ 
        end
        it "should set an org token cookie" do
          r = @authed.make_https_request('https://sandbox.democracyinaction.org/save?xml&object=supporter&Email=rd_test@email.com')
          r['set-cookie'].should =~ /org74token/
          # set-cookie expires date is one month from now
        end
      end
    end
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
