require File.dirname(__FILE__) + "/../../spec_helper"

describe DemocracyInAction::API do
  before do
    @api = DemocracyInAction::API.new( api_arguments ) 
    #Net::HTTP::Post.stub!(:new).and_return(stub_everything)
  end

  describe "build_body" do
    it "should convert key value pair into string" do
      body = @api.send(:build_body, {"key" => "123456"})
      body.should == "key=123456"
    end
    it "should convert multiple key value pairs into string" do
      body = @api.send(:build_body, {"key" => "123456", "email" => "test@domain.org"})
      body.should == "key=123456&email=test%40domain.org"
    end
    it "should convert key value pairs that contain arrays into string" do
      body = @api.send(:build_body, {"key" => "123456", "names" => ["austin", "patrice", "seth"]})
      body.should == "names=austin&names=patrice&names=seth&key=123456"
    end
  end

  describe "disabling" do
    it "is not disabled by default" do
      DemocracyInAction::API.should_not be_disabled
    end

    describe "when disabled" do
      before(:all) do
        DemocracyInAction::API.disable!
      end

      after(:all) do
        class DemocracyInAction::API; @@disabled=false; end
      end

      it "should provide ability to disable actually posting data to DIA" do
        DemocracyInAction::API.should be_disabled
      end
    end
  end

  describe "cookies" do
    it "should have cookies" do
      @api.send(:cookies).should be_an_instance_of(Array)
    end
    it "accepts and keeps cookies" do
      @api.send(:cookies).<< 'blah'
      @api.send(:cookies).<< 'blah' 
      @api.send(:cookies).size.should == 2
    end
  end

  describe "get" do

    describe "with multiple keys" do
      it "doesn't change requests without keys" do
        start_hash = { 'test' => 5, "blah" => 2 }
        @api.send(:key_param, start_hash.dup ).should == {}
      end
      it "doesn't change singular keys" do
        start_hash = { 'test' => 5, "blah" => 2, :key => "scram" }
        @api.send(:key_param, start_hash.dup ).should == { :key => 'scram' }
      end
      it "changes arrays of keys" do
        start_hash = { 'test' => 5, "blah" => 2, 'key' => [ "scram", 'suckah'] }
        @api.send(:key_param, start_hash.dup ).should_not == start_hash
      end
      it "changes arrays of keys to comma-delimited strings" do
        start_hash = { 'test' => 5, "blah" => 2, 'key' => [ "scram", 'suckah'] }
        @api.send(:key_param, start_hash.dup )['key'].should == "scram, suckah"
      end
    end

    describe "with options_for_get" do
      it "should call key_param" do
        @api.should_receive(:key_param).and_return({})
        @api.send(:options_for_get, {} )
      end
      it "should call where_param" do
        @api.should_receive(:where_param).and_return({})
        @api.send(:options_for_get, {} )
      end
      describe "a :where parameter with a hash" do

        it "should convert to an 'AND' delimited string" do
          @api.send(:options_for_get, { :table => 'test', :where => { :Email => 'joe@example.com', :Last_Name => 'Biden' }})[:where].should match(/Last_Name = 'Biden' AND Email = 'joe@example.com'|Email = 'joe@example.com' AND Last_Name = 'Biden'/)
        end

        it "should escape values with single quotes in them" do
          #@api.send(:options_for_get, 'test', { :where => { :Email => 'joe@example.com', :Last_Name => "Bi'den" }})[:where].should == "Last_Name = 'Bi\\'den' AND Email = 'joe@example.com'"
          @api.send(:options_for_get, { :where => { :Email => 'joe@example.com', :Last_Name => "Bi'den" }})[:where].should match(/Last_Name = 'Bi\\\'den' AND Email = 'joe@example.com'|Email = 'joe@example.com' AND Last_Name = 'Bi\\\'den'/)
        end
      end
      describe "a :where parameter with a string" do
        it "makes no changes" do
          simple_condition =  "Email = 'joe@example.com' AND Last_Name => 'Biden'"
          @api.send(:options_for_get, { :where => simple_condition })[:where].should == simple_condition
        end
        
      end
  
    end
  end

  describe "process" do
    describe "link hash" do
      it "raises an empty array unless it is passed a hash" do
        lambda{ @api.send(:link_hash_param, "blech")}.should raise_error(DemocracyInAction::API::InvalidData)
      end
      it "returns a hash" do
        @api.send(:link_hash_param, {} ).should be_an_instance_of(Array)
      end
      it "returns an array with the key and value pairs joined" do
        @api.send(:link_hash_param, { 'test' => '5'} ).join('&').should == 'link=test&linkKey=5'
      end
      it "returns an array with the key and value pairs joined, and value arrays processed with the keys duplicated" do
        @api.send(:link_hash_param, { 'test' => [5, 6, 7] } ).should == [ 'link=test&linkKey=5','link=test&linkKey=6','link=test&linkKey=7']
      end
      it "handles multiple table names" do
        @api.send(:link_hash_param, { 'fail' => [72,19], 'test' => [5, 6, 7] } ).should == [ 'link=fail&linkKey=72', 'link=fail&linkKey=19', 'link=test&linkKey=5','link=test&linkKey=6','link=test&linkKey=7' ]
      end
      it "gets the right stuff back after build body" do
        @api.send(:build_body, :link => { 'test' => [5, 6, 7]} ).should ==  'link=test&linkKey=5&link=test&linkKey=6&link=test&linkKey=7'
      end
    end
    describe "process_process_options" do
      it "should call process options to process the options" do
        @api.should_receive(:link_hash_param).with({"hello" => "i love you"}).and_return([])
        @api.send(:build_body, { :link => {"hello" => "i love you"}})
      end
    end
  end

  describe "send Request" do
    describe "build request" do
      it "returns a POST" do
        @api.send(:build_request, URI.parse(@api.urls[:get]), {}).should be_an_instance_of(Net::HTTP::Post)
        
      end
      it "imports the authentication to the options" do
        @api.should_receive(:build_body).with(hash_including('user'=>api_arguments[:username],'password' => api_arguments[:password] ))
        @api.send(:build_request, URI.parse(@api.urls[:get]), {})
      end

      describe "modifications" do
        before do
          @req = Net::HTTP::Post.new(URI.parse(@api.urls[:get]).path)
          Net::HTTP::Post.stub!(:new).and_return(@req)
        end
        it "appends the cookies" do
          @api.instance_variable_set( :@cookies, [ 'blah', 'blah' ] )
          @req.should_receive(:add_field).with("Cookie", 'blah').exactly(2).times
          @api.send(:build_request, URI.parse(@api.urls[:get]), {})
        end
        it "appends passed options into the body" do
          @api.should_receive(:build_body).with(hash_including(:joe =>'smokey',:ronah => 'delightful'))
          @api.send(:build_request, URI.parse(@api.urls[:get]), { :joe => 'smokey', :ronah => 'delightful' })
        end
        it "sets the content-type" do
          @req.should_receive(:set_content_type).with('application/x-www-form-urlencoded')
          @api.send(:build_request, URI.parse(@api.urls[:get]), {})
        end
      end
    end

    describe "request and resolution" do
      describe "the actual request" do
        before do
          @net_req = stub( 'request', :start => true, :error! => true, :body => true )
          Net::HTTP.stub!(:new).and_return( @net_req )
        end
        it "is sent" do
          @net_req.should_receive(:start).and_return( @net_req )
          @api.send(:send_request, @api.urls[:get], { :table => 'cheese' })
        end
        it "is resolved" do
          @net_req.stub!(:start).and_return(@net_req)
          @api.should_receive(:resolve).with(@net_req).and_return( @net_req )
          @api.send(:send_request, @api.urls[:get], { :table => 'cheese' })
        end
      end

      describe "resolution" do
        it "calls error on the response unless the response is a success" do
          req = nil
          req.should_receive(:error!)
          @api.send :resolve, req 
        end


        describe "response is a success" do
          before do
            @req = stub( 'response', :get_fields => false )
            @req.stub!(:is_a?).with(Net::HTTPSuccess).and_return(true)
          end

          it "does not call error on a success" do
            @req.should_not_receive(:error!)
            @api.send :resolve, @req 
          end

          it "extracts cookies from the response" do
            @req.stub!(:get_fields).and_return([ 'blah', 'blue', 'blunder' ] )
            @api.send :resolve, @req 
            @api.send(:cookies).should == [ 'blah', 'blue', 'blunder' ]
          end
          it "returns the first argument" do
            @api.send( :resolve, @req  ).should == @req
          end
        end
      end
    end
  end

  describe "RESTful API methods" do
    it "supports POST" do
      @api.should_receive(:process)
      @api.supporter.post
    end
    it "supports PUT" do
      @api.should_receive(:process)
      @api.supporter.put :key => 'test'
    end

    describe "PUT" do
      it "won't work unless a key is specified" do
	      lambda{@api.supporter.put}.should raise_error( DemocracyInAction::API::InvalidKey )
      end
      it "will also work with supporter and email" do
	      lambda{@api.supporter.put :Email => 1 }.should_not raise_error( DemocracyInAction::API::InvalidKey )
      end

      it "will also work with *_KEY" do
	      lambda{@api.supporter.put :supporter_KEY => 1 }.should_not raise_error( DemocracyInAction::API::InvalidKey )
      end
    end
    
  end
end
