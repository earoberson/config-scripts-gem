# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'config_scripts/version'

Gem::Specification.new do |spec|
  spec.name          = "config_scripts"
  spec.version       = ConfigScripts::VERSION
  spec.authors       = ["John Brownlee", "Efrem Roberson"]
  spec.email         = ["apps@johnbrownlee.com", "e@frem.me"]
  spec.description   =  "Library for creating trackable config scripts, and reading and writing seed data into spreadsheets"
  spec.summary       = "Config scripts and seed files for Rails"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", "> 6.0.0"

  spec.add_development_dependency "bundler", "~> 2.1"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "yard"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency 'sqlite3'
  spec.add_development_dependency 'timecop'
  spec.add_development_dependency 'generator_spec'
  spec.add_development_dependency 'rspec-rails'
end
