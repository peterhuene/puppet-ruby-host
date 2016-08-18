require 'puppet/value'

module Puppet
  # Represents a Puppet resource type parameter.
  module Parameter
    attr_reader :name, :values
    attr_accessor :doc
    alias :desc :doc=

    # Creates a new parameter class.
    # @param name [Symbol] The name of the parameter.
    # @param options [Hash] The options hash.
    # @return [Class] Returns the parameter class.
    def self.create(name, options = {})
      parameter = Class.new do
        extend Parameter
        @name = name
        @values = {}
      end

      parameter.isnamevar if options[:namevar] == true

      # Support "boolean" parameters (TODO: design a "better" way)
      if options[:parent] == Puppet::Parameter::Boolean
        parameter.newvalue(:true)
        parameter.newvalue(:false)
        parameter.newvalue(:yes)
        parameter.newvalue(:no)
      end

      parameter
    end

    # Munges the parameter's value.
    # @param block [Proc] The block to invoke to munge the value.
    def munge(&block)
      # No implementation required (munging will occur on the agent)
      nil
    end

    # Unmunges the parameter's value.
    # @param block [Proc] The block to invoke to unmunge the value.
    def unmunge(&block)
      # No implementation required (unmunging will occur on the agent)
      nil
    end

    # Declares the parameter as a namevar.
    # @return [Void]
    def isnamevar
      @isnamevar = true
      @required = true
      nil
    end

    # Determines if the parameter is a namevar.
    # @return [Boolean] Returns true if the parameter is a namevar or false if not.
    def isnamevar?
      !!@isnamevar
    end

    # Declares the parameter as required.
    # @return [Void]
    def isrequired
      # TODO: determine if the "required" functionality is needed; does not appear to be used in Puppet
      @required = true
      nil
    end

    # Determines if the parameter is required.
    # @return [Boolean] Returns true if the parameter is required or false if not.
    def required?
      !!@required
    end

    # Declares the default value for the parameter.
    # @param value [Object] The default value for the parameter.
    # @param block [Proc] The block to invoke to determine the default value.
    # @return [Void]
    def defaultto(value = nil, &block)
      # Implementation not required; the compiler will omit the value and the
      # defaultto logic will be invoked on the agent.
      nil
    end

    # Removes the default value if one was specified.
    # @return [Void]
    def nodefault
      # No implementation required
      nil
    end

    # Adds a new value to the parameter.
    # @param name [Symbol, Regexp] The value name.
    # @param options [Hash] The options hash.
    # @param block [Proc] The block to invoke when the parameter is set to the value.
    # @return [Void]
    def newvalue(name, options = {}, &block)
      value = Value.new(name)
      @values[value.name] = value

      # Options are treated as setting attributes on the value
      options.each do |k, v|
        value.send(k.to_s + "=", v)
      end

      nil
    end

    # Declares new values for the parameter.
    # @param names [Array<Symbol, Regexp>] The expected values or regexs to match values against.
    # @return [Void]
    def newvalues(*names)
      names.each do |name|
        newvalue(name)
      end
      nil
    end

    # Aliases a value to another.
    # @param name [Symbol] The alias name.
    # @param value [Symbol] The value the alias refers to.
    # @return [Void]
    def aliasvalue(name, value)
      v = @values[value]
      raise ArgumentError, "Cannot alias nonexistent value '#{value}'." if v.nil?
      v.alias(name)
      nil
    end

    # Registers a block to validate the parameter's value.
    # @param block [Proc] The block to invoke to validate the parameter's value.
    # @return [Void]
    def validate(&block)
      # No implementation required
      nil
    end

    # Gets the protocol representation of the parameter.
    # @return [Protocols::DescribeTypeResponse::Parameter] Returns the protocol representation.
    def protocol
      @protocol ||= PuppetRubyHost::Protocols::DescribeTypeResponse::Type::Parameter.new(
        name: @name.to_s,
        values: string_values,
        regexes: regex_values,
        namevar: isnamevar?
      )
    end

    # Gets the acceptable string values (with aliases).
    # @return [Array<String>] Returns the array of acceptable string values.
    def string_values
      values = []
      @values.each do |key, value|
        next if value.regex?
        values << value.name.to_s
        value.aliases.each do |a|
          values << a.to_s
        end
      end
      values
    end

    # Gets the acceptable regex values.
    # @return [Array<String>] Returns the array of acceptable regex values.
    def regex_values
      @values.select do |key, value|
        value.regex?
      end.map do |key, value|
        value.name.source
      end
    end
  end
end
