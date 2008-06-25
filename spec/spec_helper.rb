begin
  require 'spec'
rescue LoadError
  require 'rubygems'
  gem 'rspec'
  require 'spec'
end

$:.unshift(File.dirname(__FILE__) + '/../lib')
require 'democracy_in_action'
DIA_ENABLED = true
Spec::Runner.configure do |config|
	def api_arguments
    user ||= ENV['USER']
    pass ||= ENV['PASS']
    org ||= ENV['ORG']
		[{ 'authCodes' => [user, pass, org] }]
	end
	def working_api_arguments
    user = 'test'
    pass = 'test'
    org = 962
		[{ 'authCodes' => [user, pass, org] }]
	end

	def stub_responses( api )
		unless api.connected?	
			response = stub(:body => File.read(File.dirname(__FILE__) + '/fixtures/supporter_by_limit_1.xml'), :get_fields => false, :set_body_internal => false )
			Net::HTTP::Get.stub!(:new).and_return(response)
      response = stub(:body => File.read(File.dirname(__FILE__) + '/fixtures/process.xml'), :get_fields => false, :set_body_internal => false )
			Net::HTTP::Post.stub!(:new).and_return(response)
		end
	end

  def fixture_file_read(filename)
    File.read(File.dirname(__FILE__) + '/fixtures/' + filename)
  end
end
