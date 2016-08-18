# Intentionally in the Puppet namespace as these can be referenced from user code
module Puppet

  # Represents the base error for all Puppet errors
  class Error < RuntimeError
    # Gets or sets the original (nested) error.
    attr_accessor :original

    # Initializes the error.
    # @param message [String] The error message.
    # @param original [Error] The original (nested) error.
    # @return [Void]
    def initialize(message, original = nil)
      super(message)
      @original = original
    end
  end

  # Represents an invocation error
  class InvokeError < Error
    # Initializes the error.
    # @param exception [Exception] The exception that occurred during invocation.
    # @param exclude_count [Integer] The count of frames to exclude from the bottom of the backtrace.
    # @return [Void]
    def initialize(exception, exclude_count)
      super(exception.message, exception)

      # Limit the backtrace to only more recent frames
      set_backtrace(exception.backtrace[0..(exception.backtrace.count - exclude_count)] || [])
    end
  end

  # Represents a remote (RPC) error
  class RemoteError < Error
    # Stores the remote exception (as a PuppetRubyHost::Protocols::Exception)
    attr_reader :remote_exception

    # Initializes the error.
    # @param exception [PuppetRubyHost::Protocols::Exception] The remote exception.
    # @return [Void]
    def initialize(exception)
      super(exception['message'])
      @remote_exception = exception
    end
  end
end
