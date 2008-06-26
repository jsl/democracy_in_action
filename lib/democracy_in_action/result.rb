require 'ostruct'
require 'forwardable'
module DemocracyInAction
  class Result < OpenStruct
    extend Forwardable
    def_delegators :@table, *Enumerable.instance_methods
    def [](key)
      @table[key.to_sym]
    end
    def []=(key, value)
      @table[key.to_sym] = value
    end
  end
end
