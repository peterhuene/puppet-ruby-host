Gem::Specification.new do |s|
  s.name = 'puppet-ruby-host'
  s.version = '0.1.0'
  s.required_rubygems_version = Gem::Requirement.new('> 2.0.0')
  s.required_ruby_version = Gem::Requirement.new('>= 2.0.0')
  s.authors = ['Puppet, Inc.']
  s.license = 'Apache-2.0'
  s.date = '2016-07-01'
  s.description = 'Puppet RPC host.'
  s.email = 'puppet@puppet.com'
  s.executables = [ 'bin/puppet-ruby-host' ]
  s.files = Dir.glob('{bin,lib}/**/*')
  s.homepage = 'https://puppet.com'
  s.require_paths = ['lib']
  s.rubyforge_project = 'puppet-ruby-host'
  s.summary = 'RPC host for Puppet functionality written in Ruby.'
  s.specification_version = 3
end
