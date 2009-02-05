require File.dirname(__FILE__) + "/spec_helper"
require 'spec/have_the_same_xml_structure'

=begin
describe "xml documents with same structure" do
  it "should have_the_same_xml_structure_as the other" do
    fixture_file_read('supporter_by_limit_1.xml').should have_the_same_xml_structure_as(fixture_file_read('supporter_by_limit_1_sandbox.xml'))
  end
  it "should not have the same structure as different" do
    fixture_file_read('supporter_by_limit_1.xml').should_not have_the_same_xml_structure_as(fixture_file_read('event.xml'))
  end
  it "should be ok with a superset of tag" do
    first = "<one><two>hey</two></one>"
    second = "<one><two>hey></two><three>hi</three></one>"
    first.should have_the_same_xml_structure_as second
  end
end
=end
