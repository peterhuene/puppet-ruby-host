require 'puppet-ruby-host/services/base'
require 'puppet-ruby-host/protocols/type_services'
require 'puppet-ruby-host/options'
require 'puppet-ruby-host/environment'
require 'puppet-ruby-host/errors'
require 'puppet/type'

module PuppetRubyHost
  module Services
    # Represents the resource type service.
    class Type < Protocols::Type::Service
      include Base

      # Initializes the service.
      # @param options [Options] The options for the service.
      # @return [Void]
      def initialize(options)
        @options = options
      end

      # Describes a type (service contract function).
      # @param request [Protocols::DescribeTypeRequest] The describe request.
      # @param _call [Void] GRPC state object.
      # @return [Protocols::DescribeTypeResponse] Returns the describe response.
      def describe(request, _call)
        handle_exception(Protocols::DescribeTypeResponse) do
          environment = Environment.get(@options, request['environment'])
          type = environment.types.get(request['name']) if environment
          Protocols::DescribeTypeResponse.new(type: if type then type.protocol else nil end)
        end
      end
    end
  end
end
