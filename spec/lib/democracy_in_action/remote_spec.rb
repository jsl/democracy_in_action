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

  describe "responses" do
    before do
      @unauthed = DemocracyInAction::API.new( api_arguments )
      @unauthed.stub!(:authentication_failed?).and_return(false)
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
          pp [ r.body, r.to_hash ]
          r.body.should match( %r-<success table="supporter- )
        end

        it "should set an org token cookie" do
          r = @authed.make_https_request("https://sandbox.democracyinaction.org/delete?object=supporter&key=#{@key}&xml=1")
          pp [ r.body, r.to_hash ]
          r['set-cookie'].should be_nil
        end
      end
    end
  end
end
