require 'nokogiri'
module XmlStructureMatcher
  class SameXmlStructure
    def initialize(expected)  
      @expected = expected  
    end  

    def matches?(target)  
      @target = target  
      xml = Nokogiri.XML(@expected)
      Nokogiri.XML(@target).traverse do |node|
        xml.search node.path
      end
    end  

    def failure_message  
      "expected <#{@target}> to " +  
      "have the sames structure as <#{@expected}>"  
    end  

    def negative_failure_message  
      "expected <#{@target}> not to " +  
      "have the same structure as <#{@expected}>"  
    end  
  end  

  # Actual matcher that is exposed.  
  def have_the_same_xml_structure_as(expected)  
    SameXmlStructure.new(expected)
  end  
end  
