$:.push File.expand_path("../lib", __FILE__)

require 'biopieces/version'

Gem::Specification.new do |s|
  s.name              = 'biopieces'
  s.version           = BioPieces::VERSION
  s.platform          = Gem::Platform::RUBY
  s.date              = Time.now.strftime("%F")
  s.summary           = "Biopieces"
  s.description       = "Biopieces is a bioinformatic framework of tools easily used and easily created."
  s.authors           = ["Martin A. Hansen"]
  s.email             = 'mail@maasha.dk'
  s.rubyforge_project = "biopieces"
  s.homepage          = 'http://www.biopieces.org'
  s.license           = 'GPL2'
  s.rubygems_version  = "2.0.0"
  s.files             = `git ls-files`.split("\n")
  s.test_files        = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables       = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.extra_rdoc_files  = Dir["wiki/*.rdoc"]
  s.require_paths     = ["lib"]

  s.add_dependency("RubyInline", ">= 3.12.2")
  s.add_dependency("narray",     ">= 0.6.0")
  s.add_development_dependency("simplecov", ">= 0.7.1")
end