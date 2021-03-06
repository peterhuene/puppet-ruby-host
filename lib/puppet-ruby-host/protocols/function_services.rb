# Generated by the protocol buffer compiler.  DO NOT EDIT!
# Source: function.proto for package 'PuppetRubyHost.Protocols'

require 'grpc'
require_relative 'function'

module PuppetRubyHost
  module Protocols
    module Function
      # The Puppet function service.
      class Service

        include GRPC::GenericService

        self.marshal_class_method = :encode
        self.unmarshal_class_method = :decode
        self.service_name = 'PuppetRubyHost.Protocols.Function'

        # Describes a Puppet function.
        rpc :Describe, DescribeFunctionRequest, DescribeFunctionResponse
        # Invokes a Puppet function.
        rpc :Invoke, stream(InvokeFunctionRequest), stream(InvokeFunctionResponse)
      end

      Stub = Service.rpc_stub_class
    end
  end
end
