require 'fileutils'
desc 'Generate service source from protocol definition.'
task :generate do
  root = File.join(File.dirname(__FILE__), '..')
  lib = File.join(root, 'lib')
  protocols = File.join(root, 'protocols')
  outputdir = File.join(lib, 'puppet-ruby-host', 'protocols')
  FileUtils.rmtree outputdir
  FileUtils.mkdir_p outputdir
  %x{protoc -I=#{protocols} --ruby_out=#{outputdir} --grpc_out=#{outputdir} --plugin=protoc-gen-grpc=`which grpc_ruby_plugin` #{File.join(protocols, '*.proto')}}

  # Hack: the generated files don't use require_relative (see https://github.com/grpc/grpc/issues/6164)
  # Once that is fixed, please remove this code
  pattern = /^require '(?!google|grpc)(.*)'$/
  Dir.glob(File.join(outputdir, '**/*.rb')) do |path|
    source = File.read(path).gsub(pattern, 'require_relative \'\1\'')
    File.open(path, "w") { |file| file.puts source }
  end
end
