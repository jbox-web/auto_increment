# frozen_string_literal: true

require_relative 'lib/auto_increment/version'

Gem::Specification.new do |s|
  s.name        = 'auto_increment'
  s.version     = AutoIncrement::VERSION::STRING
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Felipe Diesel']
  s.email       = ['felipediesel@gmail.com']
  s.homepage    = 'http://github.com/jbox-web/auto_increment'
  s.summary     = 'Auto increment a string or integer field'
  s.description = 'Automaticaly increments a string or integer field in ActiveRecord.'
  s.license     = 'MIT'

  s.required_ruby_version = '>= 3.1.0'

  s.files = `git ls-files`.split("\n")

  s.add_dependency 'rails', '>= 7.0'
  s.add_dependency 'zeitwerk'
end
