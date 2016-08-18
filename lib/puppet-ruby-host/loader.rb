require 'thread'

module PuppetRubyHost
  class Loader
    # Initializes the loader.
    # @param options [Options] The service options.
    # @param subdir [String] The subdirectory to load files from (e.g. 'functions').
    # @param directories [Array<String>] The initial directories to search.
    # @return [Void]
    def initialize(options, subdir, directories)
      @subdir = subdir
      @directories = directories + common_directories(options)
      @objects = {}
      @mutex = Mutex.new
    end

    # Gets an object from the loader.
    # @param name The name of the object to get.
    # @return [Void] Returns the object or nil if the object does not exist.
    def get(name)
      name.downcase!
      parts = name.split('::')
      name = name.to_sym

      @mutex.synchronize do
        object = @objects[name]
        unless object || @objects.include?(name)
          @directories.each do |directory|
            path = File.join(directory, @subdir, *parts) + '.rb'
            next unless File.exists?(path)
            object = load_file(parts.last, path)
            break
          end
          # Set even if not found to record misses
          @objects[name] = object
        end
        object
      end
    end

    def self.get_context
      Thread.current.thread_variable_get(:load_context)
    end

    private
    def load_file(name, path)
      context = {
        name: name,
        path: path
      }
      begin
        Thread.current.thread_variable_set(:load_context, context)
        Kernel.load path
        context[:result]
      ensure
        Thread.current.thread_variable_set(:load_context, nil)
      end
    end

    def common_directories(options)
      directories = []

      libdir = File.join(options[:libdir], 'puppet')
      directories << libdir if Dir.exists?(libdir)

      # If Bundler is being used, don't search all gems
      unless defined? ::Bundler
        Gem::Specification.latest_specs(true).each do |spec|
          spec.require_paths.each do |require_path|
            path = File.join(spec.full_gem_path, require_path, 'puppet')
            directories << path if Dir.exists?(path)
          end
        end
      end

      $LOAD_PATH.map do |path|
        path = File.join(path, 'puppet')
        directories << path if Dir.exists?(path)
      end

      directories
    end
  end
end
