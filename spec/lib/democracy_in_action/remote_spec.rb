require File.dirname(__FILE__) + "/../../spec_helper"

describe "DIA Service" do
  before do
    @api = DemocracyInAction::API.new( working_api_arguments ) 
  end
  it "should accept key value pairs that contain arrays in the body of the request post" do
    pending
    body = @api.send(:build_body, {"key" => "123456", "names" => ["austin", "patrice", "seth"]})
    body.should == "names=austin&names=patrice&names=seth&key=123456"
  end

  describe "authentication" do
    describe "with invalid credentials" do
      describe "authentication_request" do
        before do
          @api = DemocracyInAction::API.new( api_arguments ) 
          @response = @api.authentication_request
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
      describe "authenticate" do
        before do
          @api = DemocracyInAction::API.new( api_arguments ) 
        end
        it "should return false" do
          @api.authenticate.should be_false
        end
        it "should return false in authenticated?" do
          @api.authenticate
          @api.authenticated?.should be_false
        end
        it "should raise an error" do
          pending
          lambda {@api.authenticate}.should raise_error
        end
      end
    end
    describe "with valid credentials" do
      describe "authentication_request" do
        before do
          @api = DemocracyInAction::API.new( working_api_arguments )
          @response = @api.authentication_request
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
      describe "authenticate" do
        before do
          @api = DemocracyInAction::API.new( working_api_arguments )
        end
        it "should return true" do
          @api.authenticate.should be_true
        end
        it "should return true in authenticated?" do
          @api.authenticate
          @api.authenticated?.should be_true
        end
      end
    end
  end

  describe "responses" do
    before do
      @unauthed = DemocracyInAction::API.new( api_arguments )
      @unauthed.authenticate

      @authed = DemocracyInAction::API.new( working_api_arguments )
      @authed.authenticate
      @orgkey = 74
    end

    describe "getCount" do
      describe "when not authenticated" do
        it "should have error message" do
          r = @unauthed.make_https_request('https://sandbox.democracyinaction.org/api/getCount.sjs?object=supporter')
          r.body.should =~ /<data organization_KEY="-1">/
        end
        it "should set a session cookie" do
          r = @unauthed.make_https_request('https://sandbox.democracyinaction.org/api/getCount.sjs?object=supporter')
          r['set-cookie'].should_not be_nil
        end
      end
      describe "when authenticated" do
        it "should have a success message" do
          r = @authed.make_https_request('https://sandbox.democracyinaction.org/api/getCount.sjs?object=supporter')
          r.body.should =~ /<data organization_KEY="#{@orgkey}">/
        end
        it "should set an org token cookie" do
          r = @authed.make_https_request('https://sandbox.democracyinaction.org/api/getCount.sjs?object=supporter&xml=1')
          r['set-cookie'].should be_nil
        end
      end
    end

    describe "getCounts" do
      describe "when not authenticated" do
        it "should have error message" do
          r = @unauthed.make_https_request('https://sandbox.democracyinaction.org/api/getCounts.sjs?object=supporter&groupBy=Email')
          r.body.should =~ /<data organization_KEY="-1">/
        end
        it "should set a session cookie" do
          r = @unauthed.make_https_request('https://sandbox.democracyinaction.org/api/getCounts.sjs?object=supporter')
          r['set-cookie'].should_not be_nil
        end
      end
      describe "when authenticated" do
        it "should have a success message" do
          r = @authed.make_https_request('https://sandbox.democracyinaction.org/api/getCounts.sjs?object=supporter&groupBy=Email')
          r.body.should =~ /<data organization_KEY="#{@orgkey}">/
        end
        it "should set an org token cookie" do
          r = @authed.make_https_request('https://sandbox.democracyinaction.org/api/getCounts.sjs?object=supporter')
          r['set-cookie'].should be_nil
        end
      end
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

    describe "delete" do
      before do
        r = @authed.make_https_request('https://sandbox.democracyinaction.org/save?object=supporter&Email=cool2@example.org&xml=true')
        @key = r.body[/key="(\d+)"/,1]
      end
      describe "when not authenticated" do
        it "should have error message" do
          r = @unauthed.make_https_request("https://sandbox.democracyinaction.org/delete?object=supporter&xml=1&key=#{@key}")
          r.body.should match(/error table="supporter/ )
        end
        it "should set a session cookie" do
          r = @unauthed.make_https_request("https://sandbox.democracyinaction.org/delete?object=supporter&xml=1&key=#{@key}")
          r['set-cookie'].should_not be_nil
        end
      end
      describe "when authenticated" do
        it "should have a success message" do
          r = @authed.make_https_request("https://sandbox.democracyinaction.org/delete?object=supporter&key=#{@key}&xml=1")
          r.body.should match( %r-<success table="supporter- )
        end
        it "should set an org token cookie" do
          r = @authed.make_https_request("https://sandbox.democracyinaction.org/delete?object=supporter&key=#{@key}&xml=1")
          r['set-cookie'].should be_nil
        end
      end
    end
  end
end
