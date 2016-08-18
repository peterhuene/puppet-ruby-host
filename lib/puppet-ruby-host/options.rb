require 'optparse'
require 'set'

module PuppetRubyHost
  # Represents the command line options for Puppet Ruby Host.
  class Options

    # Stores the supported services.
    SERVICES = {
        function: [
          'Puppet function service.',
          lambda do |options|
            require 'puppet-ruby-host/services/function'
            PuppetRubyHost::Services::Function.new(options)
          end
        ],
        type: [
          'Puppet resource type service.',
          lambda do |options|
            require 'puppet-ruby-host/services/type'
            PuppetRubyHost::Services::Type.new(options)
          end
        ]
    }.freeze

    # Regex for valid module names
    VARIABLE_REGEX = /\$([a-z0-9_]+)/.freeze

    # Stores the supported interpolated option variables
    INTERPOLATED_VARIABLES = [
        :codedir,
        :basemodulepath,
        :environment,
        :environmentpath,
        :libdir,
        :vardir,
    ].freeze

    # Stores the requested services.
    attr_reader :services

    # Initializes the options.
    # @param args [Array<String>] The command line options to parse.
    # @return [Void]
    def initialize(args = [])
      @values = Hash.new do |hash, key|
        hash[key] = default_for key
      end

      @services = []

      self.class.create_parser(@values).permute(args).each do |service|
        entry = SERVICES[service.to_s.to_sym]
        raise OptionParser::InvalidArgument, "#{service} is not a supported service." unless entry
        @services << entry[1].call(self)
      end
    end

    # Displays command line help.
    # @return [Void]
    def self.help
      puts create_parser
      nil
    end

    # Gets the count of options.
    # @return [Integer] Returns the count of options.
    def count
      @values.count
    end

    # Gets an option value
    # @param key The option key to get the value for.
    # @return [Object] Returns the option value or nil if the option is not set.
    def [](key)
      if INTERPOLATED_VARIABLES.include? key
        interpolate(@values[key])
      else
        @values[key]
      end
    end

    # Validates the options.
    # @return [Void]
    def validate!
      raise OptionParser::MissingArgument, 'at least one service must be specified.' if @services.empty?
    end

    # Interpolates an option value.
    # @param value [String] The value to interpolate.
    # @param guard [Set] A recursion guard to detect infinite interpolation recursion.
    # @return [String] Returns the interpolated value.
    def interpolate(value, guard = Set.new)
      matches = []
      value.scan(VARIABLE_REGEX) do |_|
        matches << Regexp.last_match
      end

      return value if matches.empty?

      result = ''
      index = 0
      matches.each do |match|
        beginning, ending = match.offset(1)
        name = match[1].to_sym
        unless INTERPOLATED_VARIABLES.include?(name)
          result << value[index..(ending - 1)]
          index = ending
          next
        end

        raise OptionParser::InvalidArgument, "option '#{name}' causes a interpolation cycle." unless guard.add?(name)
        result << value[index..(beginning - 2)] unless beginning < 2
        result << interpolate(@values[name] || '', guard)
        guard.delete name

        index = ending
      end

      result << value[index..-1]
      result
    end

    private
    def self.default_codedir
      # TODO: support defaults for Windows
      home = ENV['HOME']
      return '/etc/puppetlabs/code' if home.nil? || Process.euid == 0
      File.join(home, '.puppetlabs', 'etc', 'code')
    end

    def self.default_vardir
      # TODO: support defaults for Windows
      home = ENV['HOME']
      return '/etc/puppetlabs/code' if home.nil? || Process.euid == 0
      File.join(home, '.puppetlabs', 'opt', 'puppet', 'cache')
    end

    def default_for(option)
      # TODO: support defaults for Windows?
      case option
      when :codedir
        self.class.default_codedir
      when :basemodulepath
        '$codedir/modules:/opt/puppetlabs/puppet/modules'
      when :environmentpath
        '$codedir/environments'
      when :listen
        '0.0.0.0:3000'
      when :libdir
        '$vardir/lib'
      when :vardir
        self.class.default_vardir
      else
        nil
      end
    end

    def self.create_parser(values = {})
      # Keep options in lexicographic order
      OptionParser.new do |parser|
        parser.banner = 'Usage: puppet-ruby-host [options] <service> [<service>...]'

        parser.on('--basemodulepath PATH', 'The list of Puppet paths to use for finding global modules.') do |v|
          values[:basemodulepath] = v
        end

        parser.on('--codedir DIRECTORY', 'The Puppet code directory to use.') do |v|
          values[:codedir] = File.expand_path(v)
        end

        parser.on('--environmentpath PATH', 'The list of paths to use for finding environments.') do |v|
          values[:environmentpath] = v
        end

        parser.on('-h', '--help', 'Prints this help message.') do
          puts parser
          exit 0
        end

        parser.on('--libdir DIRECTORY', 'The Puppet lib directory to use.') do |v|
          values[:libdir] = File.expand_path(v)
        end

        parser.on('--listen ADDRESS', 'The listen address/port or UNIX socket to use (e.g. "0.0.0.0:3000" or "unix:/tmp/ipc.sock").') do |v|
          values[:listen] = v
        end

        parser.on('--vardir DIRECTORY', 'The Puppet var directory to use.') do |v|
          values[:vardir] = File.expand_path(v)
        end

        parser.separator ''
        parser.separator 'Supported services:'
        SERVICES.each do |key, value|
          parser.separator format('    %-32s %s', key, value[0])
        end
      end
    end
  end
end
