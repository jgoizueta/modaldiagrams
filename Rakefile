# encoding: utf-8

require 'bundler/gem_tasks'

task :default => :test

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  version = ModalDiagrams::VERSION

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "modaldiagrams #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
