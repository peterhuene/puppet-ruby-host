source ENV['GEM_SOURCE'] || "https://rubygems.org"

gem 'puppet-ruby-host', :path => File.dirname(__FILE__), :require => false
gem 'grpc', '~> 1.0.0', :require => false
gem 'grpc-tools', '~> 1.0.0', :require => false
gem 'rake', '10.1.1', :require => false

platforms :ruby do
  gem 'pry', :group => :development
end

group(:development, :test) do
  gem 'ruby-debug-ide', :require => false
  gem 'debase', :require => false
  gem 'rspec', '~> 3.1', :require => false
  gem 'mocha', '~> 0.10.5', :require => false
  gem 'rdoc', '~> 4.1', :platforms => [:ruby]
end

if File.exists? "#{__FILE__}.local"
  eval(File.read("#{__FILE__}.local"), binding)
end
