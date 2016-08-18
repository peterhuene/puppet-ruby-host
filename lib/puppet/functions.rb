require 'puppet-ruby-host/loader'
require 'puppet-ruby-host/protocols/function.rb'
require 'puppet-ruby-host/util/helpers'

# Minimum implementation of the Puppet 4 function API
module Puppet
  module Functions
    # Represents a Puppet function.
    class Function
      # Represents a dispatch for a Puppet function.
      class Dispatch
        attr_reader :method, :types, :names, :min, :max, :block_type, :block_name

        # Initializes the dispatch.
        # @param function [Function] The function containing the dispatch.
        # @param method [Method] The method to dispatch the call to.
        # @return [Void]
        def initialize(function, method)
          @function = function
          @method = method
          @types = []
          @names = []
          @min = 0
          @max = 0
        end

        # Registers a required parameter.
        # @param type [String] The Puppet type of the parameter.
        # @param name [Symbol] The name of the parameter.
        # @return [Void]
        def param(type, name)
          add_parameter(type, name)
          raise ArgumentError, "Required parameter '#{name}' for function '#{@function.name}' in '#{@function.file}' cannot come after optional parameters." if @min != @max
          @min += 1
          @max += 1
          nil
        end

        # Alias required_param for consistent API
        alias required_param param

        # Registers an optional parameter.
        # @param type [String] The Puppet type of the parameter.
        # @param name [Symbol] The name of the parameter.
        # @return [Void]
        def optional_param(type, name)
          add_parameter(type, name)
          @max += 1
          nil
        end

        # Registers an optional repeated parameter.
        # @param type [String] The Puppet type of the parameter.
        # @param name [Symbol] The name of the parameter.
        # @return [Void]
        def repeated_param(type, name)
          add_parameter(type, name, true)
          @max = :default
          nil
        end

        # Alias optional_repeated_param for consistent API
        alias optional_repeated_param repeated_param

        # Registers a required repeated parameter.
        # @param type [String] The Puppet type of the parameter.
        # @param name [Symbol] The name of the parameter.
        # @return [Void]
        def required_repeated_param(type, name)
          add_parameter(type, name, true)
          raise ArgumentError, "Required repeated parameter '#{name}' for function '#{@function.name}' in '#{@function.file}' cannot come after optional parameters." if @min != @max
          @min += 1
          @max = :default
          nil
        end

        # Registers a block parameter.
        # @param args [Array] The variable arguments (0 for default, 1 for name, 2 for type and name).
        # @return [Void]
        def block_param(*args)
          case args.size
          when 0
            type = 'Callable'
            name = :block
          when 1
            type = 'Callable'
            name = args[0]
          when 2
            type, name = args
          else
            raise ArgumentError, "Block parameter for function '#{@function.name}' in '#{@function.file}' accepts at most 2 arguments but was given #{args.size}."
          end

          raise ArgumentError, "Block parameter for function '#{@function.name}' in '#{@function.file}' expects a string for the type." unless type.is_a?(String)
          raise ArgumentError, "Block parameter for function '#{@function.name}' in '#{@function.file}' expects a symbol for a name." unless name.is_a?(Symbol)
          raise ArgumentError, "Block parameter for function '#{@function.name}' in '#{@function.file}' has already been defined." unless @block_type.nil?

          @block_type = type
          @block_name = name
          nil
        end

        # Registers an optional block parameter.
        # @param args [Array] The variable arguments (0 for default, 1 for name, 2 for type and name).
        # @return [Void]
        def optional_block_param(*args)
          block_param(*args)
          @block_type = "Optional[#{@block_type}]"
          nil
        end

        # Gets the protocol representation of the dispatch.
        # @return [Protocols::DescribeFunctionResponse::Function::Dispatch] Returns the protocol representation.
        def protocol
          @protocol ||= PuppetRubyHost::Protocols::DescribeFunctionResponse::Function::Dispatch.new(
            id: "#{@function.name}##{method.name.to_s}",
            name: method.name.to_s,
            types: if @types.all? { |t| t == 'Any' } then [] else @types end,
            names: @names.map { |n| n.to_s },
            min: @min,
            max: @max == :default ? -1 : @max,
            block_type: @block_type || '',
            block_name: if @block_name then @block_name.to_s else '' end,
          )
        end

        private
        def add_parameter(type, name, repeated = false)
          raise ArgumentError, "Parameter '#{name}' for function '#{@function.name}' in '#{@function.file}' cannot come after a block parameter." unless @block_type.nil?
          raise ArgumentError, "Parameter '#{name}' for function '#{@function.name}' in '#{@function.file}' cannot come after a repeated parameter." if @max == :default
          raise ArgumentError, "Parameter '#{name}' for function '#{@function.name}' in '#{@function.file}' must have a string type." unless type.is_a?(String)
          raise ArgumentError, "Parameter '#{name}' for function '#{@function.name}' in '#{@function.file}' must have a symbol name." unless name.is_a?(Symbol)
          @types << type
          @names << name
        end
      end

      attr_reader :name, :file, :line

      # Initializes a Puppet function.
      # @param name [String] The name of the function (.e.g. foo).
      # @param file [String] The file that registered the function.
      # @param line [Integer] The line in the file where the function was defined.
      # @param block [Proc] The block defining the Puppet function.
      def initialize(name, file, line, block)
        @name = name
        @file = file
        @line = line
        @dispatches = {}
        instance_eval(&block)
        add_default_dispatch
        evaluate_dispatches
      end

      # Invokes the function.
      # @param name [String] The name of the dispatch to invoke.
      # @param arguments [Array] The arguments to pass to the method.
      # @param pass_block [Boolean] True if the block should be passed or false if not.
      # @param block [Proc] The proc to pass to pass to the method.
      # @return [Void]
      def invoke(name, arguments, pass_block, &block)
        dispatch = @dispatches[name.to_sym]
        raise ArgumentError, "Unknown dispatch '#{name}' for function '#{@name}' in '#{@file}'." unless dispatch

        frame_count = caller.size + 2 # Discard this frame and the next (i.e. `call`) frame
        begin
          if pass_block
            dispatch.method.call(*arguments, &block)
          else
            dispatch.method.call(*arguments)
          end
        rescue Exception => ex
          raise Puppet::InvokeError.new(ex, frame_count)
        end
      end

      # Registers a dispatch for the function.
      # @param name [Symbol] The name of the dispatch.
      # @param block [Proc] The block to invoke to define the dispatch.
      # @return [Void]
      def dispatch(name, &block)
        raise ArgumentError, "Dispatch for function '#{@name}' in '#{@file}' expects a symbol for a name." unless name.is_a?(Symbol)
        raise ArgumentError, "Dispatch '#{name}' for function '#{@name}' in '#{@file}' already exists." if @dispatches.has_key?(name)
        @dispatches[name] = block
        nil
      end

      # Gets the protocol representation of the function.
      # @return [Protocols::DescribeFunctionResponse::Function] Returns the protocol representation.
      def protocol
        @protocol ||= PuppetRubyHost::Protocols::DescribeFunctionResponse::Function.new(
          name: @name,
          file: @file,
          line: @line,
          dispatches: @dispatches.map { |id, dispatch| dispatch.protocol }
        )
      end

      private
      def add_default_dispatch
        name = @name.split('::').last.to_sym
        return if @dispatches.has_key?(name)
        return unless respond_to?(name)

        m = method(name)
        dispatch(name) do
          m.parameters.each do |type, parameter|
            case type
            when :opt
              optional_param 'Any', parameter
            when :req
              required_param 'Any', parameter
            when :rest
              repeated_param 'Any', parameter
            when :block
              block_param
            else
              raise ArgumentError, "Parameter '#{parameter}' for function '#{id}' in '#{@file}' has an unsupported parameter type of #{type}'."
            end
          end
        end
      end

      def evaluate_dispatches
        raise ArgumentError, "Puppet function '#{@name}' in '#{@file}' contains no dispatches or a method of the same name." if @dispatches.empty?

        @dispatches.each do |key, value|
          raise ArgumentError, "Cannot create a dispatch '#{key}' for Puppet function '#{@name}' in '#{@file}' because a method of the same name does not exist." unless respond_to?(key)
          dispatch = Dispatch.new(self, method(name))
          dispatch.instance_eval(&value)
          @dispatches[key] = dispatch
        end
      end
    end

    # Call to create a Puppet function.
    # @param name [String, Symbol] The name of the Puppet function.
    # @param block [Proc] The block that defines the methods and dispatch of the Puppet function.
    # @return [Void]
    def self.create_function(name, &block)
      context = PuppetRubyHost::Loader::get_context
      raise ArgumentError, 'Puppet::Functions#create_function cannot be called without a loader context.' unless context
      raise ArgumentError, 'Puppet::Functions#create_function cannot be called more than once in a file.' if context[:result]

      site = caller[0].split(':')
      name = name.to_s.downcase
      raise ArgumentError, "Function '#{name}' defined at #{site[0]}:#{site[1]} does not match the required name of '#{context[:name]}'." unless name == context[:name]

      context[:result] = Function.new(name, site[0], site[1].to_i, block)

      nil
    end
  end
end
