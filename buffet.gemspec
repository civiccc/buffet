# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "buffet/version"

Gem::Specification.new do |s|
  s.name        = "buffet-gem"
  s.version     = Buffet::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Grant Mathews"]
  s.email       = ["grant@causes.com"]
  s.homepage    = "http://www.github.com/causes/buffet"
  s.summary     = %q{Distributed testing framework for Ruby, Rails and RSpec}
  s.description = %q{Buffet distributes RSpec test cases over multiple machines.}

  # s.rubyforge_project = "Buffet"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- spec/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency 'wopen3'
  s.add_dependency 'net-ssh'
  s.add_dependency 'json'

  s.add_development_dependency 'rspec'
  s.add_development_dependency 'mkdtemp'
end
