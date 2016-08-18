require 'puppet-ruby-host/loader'
require 'puppet-ruby-host/protocols/type'
require 'puppet/parameter'
require 'puppet/property'
require 'puppet/parameter/boolean'

# Minimum implementation of the Puppet 4 resource type API
module Puppet
  # Represents a Puppet resource type.
  module Type
    attr_reader :name, :file, :line, :properties, :parameters
    attr_accessor :doc
    alias :desc :doc=

    # Creates the 'ensure' property
    # @param block [Proc] The optional block to invoke on the ensure property.
    # @return [Void]
    def ensurable(&block)
      if block_given?
        newproperty(:ensure, &block)
      else
        newproperty(:ensure) do
          newvalue(:present)
          newvalue(:absent)
        end
      end
      nil
    end

    # Creates a new property.
    # @param name [Symbol] The name of the property.
    # @param options [Hash] The property options.
    # @param block [Proc] The block to invoke on the new property.
    # @return [Void]
    def newproperty(name, options = {}, &block)
      raise ArgumentError, 'Expected a string or symbol for property name.' unless name.is_a?(String) || name.is_a?(Symbol)
      raise ArgumentError, 'Expected a hash for the options.' unless options.is_a?(Hash)

      name = name.intern
      raise ArgumentError, "Resource type '#{self.name}' already has a property '#{name}'." if @properties.has_key?(name)
      raise ArgumentError, "Resource type '#{self.name}' already has a parameter '#{name}'." if @parameters.has_key?(name)

      property = Property.create(name, options)
      property.class_eval(&block) unless block.nil?
      @properties[name] = property
      nil
    end

    # Creates a new parameter.
    # @param name [Symbol] The name of the parameter.
    # @param options [Hash] The parameter options.
    # @param block [Proc] The block to invoke on the new parameter.
    # @return [Void]
    def newparam(name, options = {}, &block)
      raise ArgumentError, 'Expected a string or symbol for parameter name.' unless name.is_a?(String) || name.is_a?(Symbol)
      raise ArgumentError, 'Expected a hash for the options.' unless options.is_a?(Hash)

      name = name.intern
      raise ArgumentError, "Resource type '#{self.name}' already has a property '#{name}'." if @properties.has_key?(name)
      raise ArgumentError, "Resource type '#{self.name}' already has a parameter '#{name}'." if @parameters.has_key?(name)

      parameter = Parameter.create(name, options)
      parameter.class_eval(&block) unless block.nil?
      @parameters[name] = parameter
      nil
    end

    # Creates a new metaparameter.
    # @param name [Symbol] The name of the metaparameter.
    # @param options [Hash] The metaparameter options.
    # @param block [Proc] The block to invoke on the new metaparameter.
    # @return [Void]
    def newmetaparam(name, options = {}, &block)
      # TODO: raise exception or support?
      nil
    end

    # Creates a provider parameter.
    # @return [Void]
    def providify
      newparam(:provider)
      nil
    end

    # Specifies an autorequire relationship.
    # @param name [String] The name of the resource.
    # @param block [Proc] The block to invoke to get the resource titles.
    # @return [Void]
    def autorequire(name = nil, &block)
      # Not needed to describe the type
      nil
    end

    # Specifies an autobefore relationship.
    # @param name [String] The name of the resource.
    # @param block [Proc] The block to invoke to get the resource titles.
    # @return [Void]
    def autobefore(name = nil, &block)
      # Not needed to describe the type
      nil
    end

    # Specifies an autosubscribe relationship.
    # @param name [String] The name of the resource.
    # @param block [Proc] The block to invoke to get the resource titles.
    # @return [Void]
    def autosubscribe(name = nil, &block)
      # Not needed to describe the type
      nil
    end

    # Specifies an autonotify relationship.
    # @param name [String] The name of the resource.
    # @param block [Proc] The block to invoke to get the resource titles.
    # @return [Void]
    def autonotify(name = nil, &block)
      # Not needed to describe the type
      nil
    end

    # Declares a provider feature for the resource type.
    # @param name [Symbol] The feature name.
    # @param docs [String] The feature documentation string.
    # @param hash [Hash] The hash for the feature.
    def feature(name, docs, hash = {})
      # Not needed to describe the type
      nil
    end

    # Validates the type.
    # @param block [Proc] The block to invoke to validate the type.
    def validate(&block)
      # No implementation required
      nil
    end

    # Gets the protocol representation of the type.
    # @return [Protocols::DescribeTypeResponse::Type] Returns the protocol representation.
    def protocol
      @protocol ||= PuppetRubyHost::Protocols::DescribeTypeResponse::Type.new(
        name: @name,
        file: @file,
        line: @line,
        properties: @properties.map { |_, value| value.protocol },
        parameters: @parameters.map { |_, value| value.protocol }
      )
    end

    # Call to create a Puppet resource type.
    # @param name [String, Symbol] The name of the Puppet resource type.
    # @param options [Hash] The options when creating the type.
    # @param block [Proc] The block that defines the resource type.
    # @return [Void]
    def self.newtype(name, options = {}, &block)
      context = PuppetRubyHost::Loader::get_context
      raise ArgumentError, 'Puppet::Type#newtype cannot be called without a loader context.' unless context
      raise ArgumentError, 'Puppet::Type#newtype cannot be called more than once in a file.' if context[:result]

      site = caller[0].split(':')
      name = name.to_s.downcase
      raise ArgumentError, "Resource type '#{name}' defined at #{site[0]}:#{site[1]} does not match the required name of '#{context[:name]}'." unless name == context[:name]

      context[:result] = Class.new do
        @name = name
        @file = site[0]
        @line = site[1].to_i
        @properties = {}
        @parameters = {}

        extend Type
        class_eval(&block)
        set_default_namevar!
      end

      nil
    end

    private
    def set_default_namevar!
      return if @parameters.any? { |key, parameter| parameter.isnamevar? }
      if name = @parameters[:name]
        name.isnamevar
        return
      end
      raise ArgumentError, "Resource type '#{@name}' must contain at least one namevar parameter or a 'name' parameter."
    end
  end
end
