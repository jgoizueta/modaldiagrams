$:.push File.expand_path("../lib", __FILE__)

require "modaldiagrams/version"

Gem::Specification.new do |s|
  s.name        = "modaldiagrams"
  s.version     = ModalDiagrams::VERSION
  s.authors     = ["Javier Goizueta"]
  s.email       = ["jgoizueta@gmail.com"]

  s.homepage    = "https://github.com/jgoizueta/modaldiagrams"
  s.summary     = "DB diagramming tool fo Rails ActiveRecord applications"
  s.description = "modaldiagrams provides Rake tasks for diagramming ActiveRecord databases. It generates Graphviz dot files."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", ">= 3.2"

  s.add_dependency 'modalsupport', ">= 0.9.2"
  s.add_dependency 'modalsettings', ">= 0"
end
