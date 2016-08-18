require 'rake'
Dir['tasks/**/*.rake'].each { |t| load t }

task :default do
  sh %{rake -T}
end

task :spec do
  sh %{rspec #{ENV['TEST'] || ENV['TESTS'] || 'spec'}}
end
