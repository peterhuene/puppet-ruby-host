require 'puppet-ruby-host/services/base'
require 'puppet-ruby-host/protocols/function_services'
require 'puppet-ruby-host/options'
require 'puppet-ruby-host/environment'
require 'puppet-ruby-host/errors'
require 'puppet/functions'

module PuppetRubyHost
  module Services
    # Represents the function service.
    class Function < Protocols::Function::Service
      include Base

      # Initializes the service.
      # @param options [Options] The options for the service.
      # @return [Void]
      def initialize(options)
        @options = options
      end

      # Describes a function (service contract function).
      # @param request [Protocols::DescribeFunctionRequest] The describe request.
      # @param _call [Void] GRPC state object.
      # @return [Protocols::DescribeFunctionResponse] Returns the describe response.
      def describe(request, _call)
        handle_exception(Protocols::DescribeFunctionResponse) do
          environment = Environment.get(@options, request['environment'])
          function = environment.functions.get(request['name']) if environment
          Protocols::DescribeFunctionResponse.new(function: if function then function.protocol else nil end)
        end
      end

      # Invokes a function (service contract function).
      # @param stream [Iterable] The stream of request messages.
      # @return [Iterable] Returns a stream of response messages.
      def invoke(stream)
        Enumerator.new do |responder|
          responder.yield(handle_exception(Protocols::InvokeFunctionResponse) do
            # Read the initial request (must be a function call)
            request = stream.next
            raise ArgumentError, 'Expected a call request.' unless request.kind == :call
            call_request = request['call']
            function_name, dispatch_name = call_request['id'].split('#')
            raise ArgumentError, "Invalid dispatch id #{call_request['id']}." if dispatch_name.nil?

            # Find the requested function
            environment = Environment.get(@options, call_request['environment'])
            function = environment.functions.get(function_name) if environment
            raise ArgumentError, "Unknown function '#{function_name}'." if function.nil?

            # Invoke the function
            result = function.invoke(dispatch_name, call_request['arguments'].map { |x| Util::to_ruby(x) }, call_request['has_block']) do |*args|
              # Send a yield
              responder.yield Protocols::InvokeFunctionResponse.new(
                yield: Protocols::InvokeFunctionResponse::Yield.new(arguments: args.map { |x| Util::to_value(x) })
              )

              # Get the response to the yield
              response = stream.next
              raise ArgumentError, 'Expected a continuation response.' unless response.kind == :continuation
              continuation = response['continuation']

              case continuation.kind
              when :result
                Util::to_ruby(continuation['result'])
              when :exception
                raise Puppet::RemoteError.new(continuation['exception'])
              else
                raise ArgumentError, 'Expected a result or exception.'
              end
            end

            Protocols::InvokeFunctionResponse.new(result: Util::to_value(result))
          end)
        end
      end
    end
  end
end
