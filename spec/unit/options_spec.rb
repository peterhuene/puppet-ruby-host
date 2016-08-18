require 'spec_helper'
require 'puppet-ruby-host/options'

describe PuppetRubyHost::Options do

  subject { PuppetRubyHost::Options }

  before :all do
    @tmpdir = Dir.mktmpdir
  end

  after :all do
    FileUtils.remove_entry @tmpdir
  end

  describe 'parsing options' do
    it 'should parse empty options' do
      options = subject.new
      expect(options.services.empty?).to be(true)
      expect(options.count).to be(0)
    end

    it 'should parse with a single specified service' do
      name, info = subject::SERVICES.first

      options = subject.new([name])
      expect(options.services.first.class).to eq(info[1].call(options).class)
    end

    it 'should accept a code directory that exists' do
      expect(subject.new(["--codedir=#{@tmpdir}"])[:codedir]).to eq(@tmpdir)
    end

    it 'should accept a var directory that exists' do
      expect(subject.new(["--vardir=#{@tmpdir}"])[:vardir]).to eq(@tmpdir)
    end

    it 'should accept a lib directory' do
      expect(subject.new(['--libdir=foo'])[:libdir]).to eq(File.expand_path('foo'))
    end

    it 'should accept an environment path' do
      environmentpath = 'foo:bar:baz'
      expect(subject.new(["--environmentpath=#{environmentpath}"])[:environmentpath]).to eq(environmentpath)
    end

    it 'should accept a module path' do
      basemodulepath = 'foo:bar:baz'
      expect(subject.new(["--basemodulepath=#{basemodulepath}"])[:basemodulepath]).to eq(basemodulepath)
    end

    it 'should reject an unknown option a module path' do
      expect{ subject.new(["--unknown"]) }.to raise_error(OptionParser::InvalidOption, 'invalid option: --unknown')
    end
  end

  describe 'validating options' do
    it 'should require at least one service specified' do
      expect{ subject.new.validate! }.to raise_error(OptionParser::MissingArgument, 'missing argument: at least one service must be specified.')
    end
  end

  describe 'dispalying help' do
    it 'should output the expected help' do
      expect{ subject.help }.to output(<<OUTPUT
Usage: puppet-ruby-host [options] <service> [<service>...]
        --basemodulepath PATH        The list of Puppet paths to use for finding global modules.
        --codedir DIRECTORY          The Puppet code directory to use.
        --environmentpath PATH       The list of paths to use for finding environments.
    -h, --help                       Prints this help message.
        --libdir DIRECTORY           The Puppet lib directory to use.
        --listen ADDRESS             The listen address/port or UNIX socket to use (e.g. "0.0.0.0:3000" or "unix:/tmp/ipc.sock").
        --vardir DIRECTORY           The Puppet var directory to use.

Supported services:
    dispatch                         Puppet function dispatch service.
OUTPUT
    ).to_stdout
    end
  end

  describe 'interpolating variables' do
    it 'should interpolate a single variable reference' do
      options = subject.new(["--codedir=#{@tmpdir}", '--basemodulepath=foo:$codedir:bar'])
      expect(options[:basemodulepath]).to eq("foo:#{@tmpdir}:bar")
    end

    it 'should interpolate multiple variable references' do
      options = subject.new(["--codedir=#{@tmpdir}", '--basemodulepath=foo:$codedir:bar:$codedir:$environmentpath', '--environmentpath=jam'])
      expect(options[:basemodulepath]).to eq("foo:#{@tmpdir}:bar:#{@tmpdir}:jam")
    end

    it 'should recursively interpolate variable references' do
      options = subject.new(["--codedir=#{@tmpdir}", '--basemodulepath=foo:$codedir', '--environmentpath=$basemodulepath:baz'])
      expect(options[:environmentpath]).to eq("foo:#{@tmpdir}:baz")
    end

    it 'should detect interpolation cycles' do
      expect{ subject.new(["--codedir=#{@tmpdir}", '--basemodulepath=foo:$environmentpath', '--environmentpath=$basemodulepath:baz'])[:environmentpath] }.to(
          raise_error(OptionParser::InvalidArgument, 'invalid argument: option \'basemodulepath\' causes a interpolation cycle.')
      )
    end
  end
end
