require 'puppet-ruby-host/protocols/exception'
require 'puppet-ruby-host/protocols/value'
require 'puppet-ruby-host/errors'

module PuppetRubyHost
  module Util
    # Expression to extract information from Ruby stack traces.
    BACKTRACE_REGEX = /(.*?):(\d+)(?::in `(.*?)')?/.freeze

    # Converts a Ruby object to a protocol value.
    # @param obj [Object] The object to convert to a protocol value.
    # @return [Protocols::Value] Returns the protocol value representation of the Ruby object.
    def self.to_value(obj)
      case obj
      when nil
        Protocols::Value.new(symbol: Protocols::Value::Symbol::UNDEF)
      when :default
        Protocols::Value.new(symbol: Protocols::Value::Symbol::DEFAULT)
      when Integer
        Protocols::Value.new(integer: obj)
      when Float
        Protocols::Value.new(float: obj)
      when TrueClass, FalseClass
        Protocols::Value.new(boolean: obj)
      when Symbol
        # Treat symbols as strings
        Protocols::Value.new(string: obj.to_s)
      when String
        Protocols::Value.new(string: obj)
      # TODO: implement
      #when TYPE
      when Regexp
        Protocols::Value.new(regex: obj.source)
      when Array
        Protocols::Value.new(array: Protocols::Value::Array.new(elements: obj.map { |x| to_value(x) }))
      when Hash
        Protocols::Value.new(hash: Protocols::Value::Hash.new(elements: obj.map { |key, value|
          Protocols::Value::Hash::KeyValuePair.new(key: to_value(key), value: to_value(value))
        }))
      else
        raise ArgumentError, "#{obj.class} is not a supported Puppet type."
      end
    end

    # Converts a protocol value to a Ruby object.
    # @param value [Protocols::Value] The protocol value to convert to a Ruby object.
    # @return [Object] Returns the Ruby representation of the protocol value.
    def self.to_ruby(value)
      case value.kind
      when :symbol
        case value['symbol']
        when :UNDEF
          nil
        when :DEFAULT
          :default
        else
          raise ArgumentError, "#{value['symbol']} is not a supported symbolic value."
        end
      when :default
        :default
      when :integer
        value['integer']
      when :float
        value['float']
      when :boolean
        value['boolean']
      when :string
        value['string']
      when :regexp
        Regexp.new(value['regexp'])
      when :type
        # TODO: stop treating types as strings
        value['type']
      when :array
        value['array'].elements.map { |x| to_ruby(x) }
      when :hash
        result = {}
        value['hash'].elements.each { |kvp| result[to_ruby(kvp['key'])] = to_ruby(kvp['value']) }
        result
      else
        raise ArgumentError, "#{value.kind} is not a supported Puppet type."
      end
    end

    # Converts a Ruby exception to a protocol exception.
    # @param ex [Exception] The Ruby exception to convert.
    # @param filter_regex [Regexp] The filter to apply to the frames.
    # @return [Protocols::Exception] Returns the protocol representation of the exception.
    def self.to_protocol_exception(ex, filter_regex = nil)
      if ex.is_a?(Puppet::InvokeError) && ex.original.is_a?(Puppet::RemoteError)
        # Use the context from the remote exception and start with its backtrace as the top of the stack
        context = ex.original.remote_exception['context']
        frames = ex.original.remote_exception['backtrace']
      end
      frames ||= []
      ex.backtrace.each do |frame|
        next if filter_regex && frame =~ filter_regex
        next unless frame =~ BACKTRACE_REGEX
        frames << Protocols::Exception::StackFrame.new(
          name: $3,
          file: $1,
          line: $2.to_i
        )
      end
      Protocols::Exception.new(
        message: ex.message.encode('UTF-8'),
        context: context,
        backtrace: frames.to_a
      )
    end
  end
end
