require File.dirname(__FILE__) + '/../../spec_helper'

describe "DemocracyInAction::API when getting" do
	before do
    @api = DemocracyInAction::API.new( working_api_arguments )
	end

  describe "supporters" do
    before do
      @supporter = @api.first(:object => 'supporter')
    end
    it "gets one" do
      @supporter.supporter_KEY.should_not be_nil
    end

    it "should return a single object when getting by key" do
      @api.get(:object => 'supporter', :key => @supporter.key).should be_an_instance_of(DemocracyInAction::Result)
    end

    it "gets the same object with key" do
      first = @api.first(:object => 'supporter')
      supporter = @api.get(:object => 'supporter', :key => first.key)
      first.should == supporter
    end

    it "posts" do
      supporter_key = @api.save(:object => 'supporter', :xml => true, :Email => 'test@radicaldesigns.org', :First_Name => 'austin')
      supporter_key.should match(/\d+/)
    end

    describe "table proxy" do
      it "also gets one" do
        @api.supporter.first.supporter_KEY.should_not be_nil
      end
      it "works with plural table name as well" do
        pending
        @api.supporters.first.supporter_KEY.should_not be_nil
      end
    end
  end
end
