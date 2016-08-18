require 'puppet/parameter'

module Puppet
  # Represents a Puppet resource type property.
  # Inherits all functionality from Parameter.
  module Property
    # Creates a new property class.
    # @param name [Symbol] The name of the property.
    # @param options [Hash] The options hash.
    # @return [Class] Returns the property class.
    def self.create(name, options = {})
      Class.new do
        extend Parameter
        @name = name
        @values = {}
      end
    end
  end
end
