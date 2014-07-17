#! /your/favourite/path/to/gem
# -*- coding: utf-8; mode: ruby; ruby-indent-level: 2 -*-
#
# Copyright (c) 2014 Urabe, Shyouhei
#
# Permission is hereby granted, free of  charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction,  including without limitation the rights
# to use,  copy, modify,  merge, publish,  distribute, sublicense,  and/or sell
# copies  of the  Software,  and to  permit  persons to  whom  the Software  is
# furnished to do so, subject to the following conditions:
#
#        The above copyright notice and this permission notice shall be
#        included in all copies or substantial portions of the Software.
#
# THE SOFTWARE  IS PROVIDED "AS IS",  WITHOUT WARRANTY OF ANY  KIND, EXPRESS OR
# IMPLIED,  INCLUDING BUT  NOT LIMITED  TO THE  WARRANTIES OF  MERCHANTABILITY,
# FITNESS FOR A  PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO  EVENT SHALL THE
# AUTHORS  OR COPYRIGHT  HOLDERS  BE LIABLE  FOR ANY  CLAIM,  DAMAGES OR  OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'rubygems'
require_relative 'lib/space_observatory/version'

Gem::Specification.new do |gem|
  gem.name          = "space_observatory"
  gem.version       = SpaceObservatory::VERSION
  gem.authors       = ["Urabe, Shyouhei"]
  gem.email         = ["shyouhei@ruby-lang.org"]
  gem.summary       = "ObjectSpace#dump_all exposed"
  gem.description   = "Pure-ruby Minimal-overhead Drop-in probe to ObjectSpace."
  gem.homepage      = "https://github.com/shyouhei/space_observatory"
  gem.license       = "MIT"

  gem.files         = `git ls-files -z`.split("\x0")
  gem.executables   = gem.files.grep(%r{^exec/}) { |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.required_ruby_version = '~> 2.1'
  gem.add_development_dependency 'yard',      '~> 0.8'
  gem.add_development_dependency 'rdoc',      '~> 4.0'
  gem.add_development_dependency 'rspec',     '~> 3.0'
  gem.add_development_dependency 'rspec-its'
  gem.add_development_dependency 'simplecov', '>= 0'
  gem.add_development_dependency 'bundler',   '~> 1.6'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'pry'
  gem.add_dependency 'rack' # we use pure-rack
  gem.add_dependency 'slop'
end
