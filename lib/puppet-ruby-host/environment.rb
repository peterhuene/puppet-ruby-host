require 'thread'
require 'puppet-ruby-host/loader'

module PuppetRubyHost
  # Represents a Puppet environment
  class Environment
    # The expression for valid module names
    VALID_MODULE_REGEX = /^[a-z][a-z0-9_]*$/.freeze

    # Mutex for synchronizing access to environments
    @@environments_mutex = Mutex.new
    @@environments = {}

    attr_reader :name, :directory, :functions, :types

    # Initializes the environment.
    # @param options [Options] The service options.
    # @param name [String] The name of the environment.
    # @param directory [String] The environment directory.
    # @return [Void]
    def initialize(options, name, directory)
      @name = name
      @directory = directory
      @module_directories = module_directories(options)
      @functions = Loader.new(options, 'functions', @module_directories)
      @types = Loader.new(options, 'type', @module_directories)
    end

    # Gets an environment.
    # @param options [Options] The service options.
    # @param name [String] The name of the environment.
    # @return [Environment] Returns the environment if found or nil if the environment does not exist.
    def self.get(options, name)
      @@environments_mutex.synchronize do
        environment = @@environments[name.to_sym]
        unless environment
          options[:environmentpath].split(File::PATH_SEPARATOR).each do |path|
            directory = File.join(path, name)
            next unless Dir.exists?(directory)
            environment = Environment.new(options, name, directory)
            @@environments[name.to_sym] = environment
          end
        end
        environment
      end
    end

    # Resets an environment.
    # @param name [String] The name of the environment to reset.
    def self.reset!(name)
      @@environments_mutex.synchronize do
        @@environments.delete name.to_sym
      end
    end

    private
    def module_directories(options)
      directories = []

      # TODO: support reading the module path from environment.conf
      options.interpolate('modules:$basemodulepath').split(File::PATH_SEPARATOR).each do |path|
        modules_dir = File.expand_path(path, @directory)
        next unless Dir.exists?(modules_dir)

        Dir.glob("#{modules_dir}/*").each do |module_dir|
          next unless File.basename(module_dir) =~ VALID_MODULE_REGEX
          next unless File.directory?(module_dir)

          directory = File.join(module_dir, 'lib', 'puppet')
          next unless Dir.exists?(directory)
          directories << directory
        end
      end

      directories
    end
  end
end
