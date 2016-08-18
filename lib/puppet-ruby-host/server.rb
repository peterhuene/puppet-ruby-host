require 'grpc'

module PuppetRubyHost
  class Server
    # Initializes the RPC server.
    # @param options [Options] The service options.
    # @return [Void]
    def initialize(options)
      @server = GRPC::RpcServer.new
      @server.add_http2_port(options[:listen], :this_port_is_insecure)
      options.services.each do |service|
        @server.handle(service)
      end
    end

    # Runs the RPC server until a SIGINT signal.
    # @return [Void]
    def run
      raise 'Server has shutdown.' unless @server
      @server.run_till_terminated
      @server = nil
    end
  end
end
