begin
  require 'spec'
rescue LoadError
  require 'rubygems'
  gem 'rspec'
  require 'spec'
end

$:.unshift(File.dirname(__FILE__) + '/../lib')
require 'pp'
require 'democracy_in_action'
Spec::Runner.configure do |config|
	def api_arguments
    user = ENV['DIA_USER'] || 'dummy'
    pass = ENV['DIA_PASS'] || 'secret'
    org = ENV['DIA_ORG'] || 111
    domain = ENV['DIA_DOMAIN'] || :salsa
    {:username => user, :password => pass, :orgkey => org, :domain => domain}
	end
	def working_api_arguments
    user = ENV['DIA_USER'] || 'test'
    pass = ENV['DIA_PASS'] || 'test'
    org = ENV['DIA_ORG'] || 962 
    domain = ENV['DIA_DOMAIN'] || :salsa
    {:username => user, :password => pass, :orgkey => org, :domain => domain}
	end

  def fixture_file_read(filename)
    File.read(File.dirname(__FILE__) + '/fixtures/' + filename)
  end
end
