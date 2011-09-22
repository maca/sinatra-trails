# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "sinatra/trails/version"

Gem::Specification.new do |s|
  s.name        = "sinatra-trails"
  s.version     = Sinatra::Trails::VERSION
  s.authors     = ["Macario"]
  s.email       = ["macarui@gmail.com"]
  s.homepage    = "http://github.com/maca/trails"
  s.summary     = %q{A named routes Sinatra DSL inspired by Rails routing}
  s.description = %q{A named routes Sinatra DSL inspired by Rails routing}

  s.rubyforge_project = "sinatra-trails"
  s.add_dependency 'sinatra'
  s.add_dependency 'i18n'
  s.add_dependency 'activesupport', '>= 3.0'

  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rack-test'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
