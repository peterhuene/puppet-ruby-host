module Puppet
  # Represents a Puppet property/parameter value.
  class Value
    attr_reader :name, :aliases
    attr_accessor :required_features, :invalidate_refreshes, :event

    # Initializes a new value.
    # @param name [Symbol] The name of the value.
    # @return [Void]
    def initialize(name)
      if name.is_a?(Regexp)
        @name = name
      else
        @name = normalize(name)
      end
      @aliases = []
    end

    # Aliases the value to the given name.
    # @param name [Symbol] The alias name.
    # @return [Void]
    def alias(name)
      @aliases << normalize(name)
      nil
    end

    # Determines if the value is a regex.
    # @return [Boolean] True if the value is a regex or false if not.
    def regex?
      @name.is_a?(Regexp)
    end

    private
    def normalize(value)
      case value
      when Symbol, ''
        value
      when String
        value.intern
      when true
        :true
      when false
        :false
      else
        value.to_s.intern
      end
    end
  end
end
