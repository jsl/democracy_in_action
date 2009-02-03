require File.dirname(__FILE__) + "/../../spec_helper"

SANDBOX = 'https://sandbox.salsalabs.com'

describe "DIA Service" do
  before do
    @api = DemocracyInAction::API.new( working_api_arguments ) 
  end

  describe "authentication" do
    describe "with invalid credentials" do
      describe "authentication_request" do
        before do
          @api = DemocracyInAction::API.new( api_arguments ) 
          @api.authenticate rescue DemocracyInAction::API::ConnectionInvalid
          @response = @api.auth_response
        end
        it "should return 200" do
          @response.status.should == 200
        end
        it "should have an error message" do
          @response.content.should match(/Invalid login/)
        end
        it "should redirect to login" do
           pending
          @response['location'].should =~ /login.jsp/
        end
      end
      describe "authenticate" do
        before do
          @api = DemocracyInAction::API.new( api_arguments ) 
        end
        it "should return false" do
          lambda { @api.authenticate }.should raise_error
        end
        it "should return false in authenticated?" do
          @api.authenticate rescue DemocracyInAction::API::ConnectionInvalid
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
          @api.authenticate
          @response = @api.auth_response
        end
        it "should return 200" do
          @response.status.should == 200
        end
        it "should have show success message" do
          @response.content.should =~ /Successful Login/
        end
      end
      describe "authenticate" do
        before do
          @api = DemocracyInAction::API.new( working_api_arguments )
        end
        it "should return true" do
          @api.authenticate.should_not be_nil
        end
        it "should not raise error" do
          lambda { @api.authenticate }.should_not raise_error
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
      begin
        @unauthed.authenticate
      rescue DemocracyInAction::API::ConnectionInvalid
      end

      @authed = DemocracyInAction::API.new( working_api_arguments )
      @authed.authenticate
      @orgkey = 74
    end

    describe "getCount" do
      describe "when not authenticated" do
        before do
          @r = @unauthed.send(:client).get("#{SANDBOX}/api/getCount.sjs?object=supporter")
        end
        it "should have error message" do
          @r.body.content.should =~ /<data organization_KEY="-1">/
        end
      end
      describe "when authenticated" do
        before do
          @r = @authed.send(:client).get("#{SANDBOX}/api/getCount.sjs?object=supporter")
        end
        it "should have a success message" do
          @r.body.content.should =~ /<data organization_KEY="#{@orgkey}">/
        end
      end
    end

    describe "getCounts" do
      describe "when not authenticated" do
        before do
          @r = @unauthed.send(:client).get("#{SANDBOX}/api/getCounts.sjs?object=supporter&groupBy=Email")
        end
        it "should have error message" do
          @r.body.content.should =~ /<data organization_KEY="-1">/
        end
      end
      describe "when authenticated" do
        before do
          @r = @authed.send(:client).get("#{SANDBOX}/api/getCounts.sjs?object=supporter&groupBy=Email")
        end
        it "should have a success message" do
          @r.body.content.should =~ /<data organization_KEY="#{@orgkey}">/
        end
      end
    end

    describe "getObject" do
      describe "when not authenticated" do
        before do
          @r = @unauthed.send(:client).get("#{SANDBOX}/api/getObject.sjs?object=supporter&key=-1")
        end
        it "should have organization_KEY undefined" do
          @r.body.content.should =~ /<data organization_KEY="undefined">/
        end
      end
      describe "when authenticated" do
        before do
          @r = @authed.send(:client).get("#{SANDBOX}/api/getObject.sjs?object=supporter&key=-1")
        end
        it "should ALSO have organization_KEY undefined if we don't have access" do
          @r.body.content.should =~ /<data organization_KEY="undefined">/
        end
      end
    end

    describe "getObjects" do
      describe "when not authenticated" do
        before do
          @r = @unauthed.send(:client).get("#{SANDBOX}/api/getObjects.sjs?object=supporter&limit=0")
        end
        it "should have organization_KEY == -1" do
          @r.body.content.should =~ /<data organization_KEY="-1">/
        end
      end
      describe "when authenticated" do
        before do
          @r = @authed.send(:client).get("#{SANDBOX}/api/getObjects.sjs?object=supporter&limit=0")
        end
        it "should have organization_KEY == your organization key" do
          @r.body.content.should =~ /<data organization_KEY="#{@orgkey}">/
        end
      end
    end

    describe "save" do
      describe "when not authenticated" do
        before do
          @r = @unauthed.send(:client).get("#{SANDBOX}/save?xml&object=supporter&Email=rd_test@email.com")
        end
        it "should have error message" do
          @r.body.content.should =~ /<error object="supporter"/ 
        end
      end
      describe "when authenticated" do
        before do
          @r = @authed.send(:client).get("#{SANDBOX}/save?xml&object=supporter&Email=rd_test@email.com")
        end
        it "should have a success message" do
          @r.body.content.should =~ /<success object="supporter"/ 
        end
      end
    end

    describe "delete" do
      before do
        r = @authed.send(:client).get("#{SANDBOX}/save?object=supporter&Email=cool2@example.org&xml=true")
        @key = r.body.content[/key="(\d+)"/,1]
      end
      describe "when not authenticated" do
        before do
          @r = @unauthed.send(:client).get("#{SANDBOX}/delete?object=supporter&xml=1&key=#{@key}")
        end
        it "should have error message" do
          @r.body.content.should match(/error table="supporter/ )
        end
      end
      describe "when authenticated" do
        before do
          @r = @authed.send(:client).get("#{SANDBOX}/delete?object=supporter&key=#{@key}&xml=1")
        end
        it "should have a success message" do
          @r.body.content.should match( %r-<success table="supporter- )
        end
      end
    end

    # test our assumptions about DIA html responses
    # new API is supposed to require an authentication request first
    # i'm skeptical this is the case for this method (email)
    #
    # https://salsa.democracyinaction.org/email?xml&to=seth.h.walker@gmail.com&cc=seth%2Bcc@radicaldesigns.org&username=test&password=test&subject=test&from=seth%2Bfrom@radicaldesigns.org&bcc=seth%2Bbcc@radicaldesigns.org&content=testing
    describe "email" do
      before do 
        @success =%r{<br/>Testing\ for\ spam:\ false}
        @spam_response = %r|<br/>Testing for spam: falseThanks!  Your message has been sent.|
        @valid_args = "xml&to=nobody@example.com&subject=test&from=nobody@example.com"
      end
      describe "when not authenticated" do
        before do
          @r = @unauthed.send(:client).get("#{SANDBOX}/email?#{@valid_args}")
        end
        it "reports email is successfully sent" do
          @r.body.content.should match( @success )
        end
      end
      describe "when authenticated" do
        before do
          @r = @authed.send(:client).get("#{SANDBOX}/email?#{@valid_args}")
        end
        it "should have a success message" do
          @r.body.content.should match( @success )
        end
      end
      describe "content trips spam filter" do
        before do
          @r = @authed.send(:client).get("#{SANDBOX}/email?#{@valid_args}&content=viagra")
        end
        it "reports success and includes additional affirmation the mesg has been sent" do
          @r.body.content.should match(@spam_response)
        end
      end
    end
  end
end
