require 'puppet-ruby-host/util/helpers'

module PuppetRubyHost
  module Services
    # Represents the base service
    module Base
      # The filter to remove extra frames from backtraces
      BACKTRACE_FILTER = /\/(?:grpc|puppet-ruby-host)\//.freeze

      def handle_exception(type, &block)
        begin
          block.call
        rescue Exception => ex
          type.new(
              exception: Util::to_protocol_exception(ex, BACKTRACE_FILTER)
          )
        end
      end
    end
  end
end
