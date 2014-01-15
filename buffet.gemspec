# -*- encoding: utf-8 -*-
$:.push File.expand_path('../lib', __FILE__)
require 'buffet/version'

Gem::Specification.new do |s|
  s.name        = 'buffet'
  s.version     = Buffet::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Causes Engineering']
  s.email       = ['eng@causes.com', 'grant@causes.com', 'shane@causes.com']
  s.homepage    = 'http://github.com/causes/buffet'
  s.license     = 'MIT'
  s.summary     = 'Distributed testing framework for RSpec'
  s.description = 'Buffet distributes RSpec test cases over multiple machines.'

  s.files         = `git ls-files -- lib support`.split("\n")
  s.executables   = ['buffet']
  s.require_paths = ['lib']

  s.add_dependency 'colorize', '0.6.0'
  s.add_dependency 'wopen3', '0.3'

  s.add_development_dependency 'rspec', '2.6.0'
  s.add_development_dependency 'mkdtemp', '1.2.1'
end
