# -*- encoding: utf-8 -*-
$:.push File.expand_path('../lib', __FILE__)
require 'buffet/version'

Gem::Specification.new do |s|
  s.name        = 'minimal-buffet'
  s.version     = Buffet::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Causes Engineering']
  s.email       = ['eng@causes.com', 'grant@causes.com', 'shane@causes.com']
  s.homepage    = 'http://github.com/causes/buffet'
  s.summary     = 'Distributed testing framework for Ruby, Rails and RSpec'
  s.description = 'Buffet distributes RSpec test cases over multiple machines.'

  s.files         = `git ls-files -- lib support`.split("\n")
  s.test_files    = `git ls-files -- spec/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ['lib']

  s.add_dependency 'wopen3'

  s.add_development_dependency 'rspec'
  s.add_development_dependency 'mkdtemp'
end
