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

  s.required_ruby_version = '>= 3.0.0'

  s.files = `git ls-files`.split("\n")

  s.add_runtime_dependency 'rails', '>= 6.1'
  s.add_runtime_dependency 'zeitwerk'

  s.add_development_dependency 'appraisal'
  s.add_development_dependency 'database_cleaner'
  s.add_development_dependency 'guard-rspec'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec-rails'
  s.add_development_dependency 'rubocop'
  s.add_development_dependency 'rubocop-rake'
  s.add_development_dependency 'rubocop-rspec'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'sqlite3', '~> 1.5.0'

  if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("3.1.0")
    s.add_development_dependency 'net-imap'
    s.add_development_dependency 'net-pop'
    s.add_development_dependency 'net-smtp'
  end

  if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("3.4.0")
    s.add_development_dependency "base64"
    s.add_development_dependency "bigdecimal"
    s.add_development_dependency "mutex_m"
    s.add_development_dependency "drb"
    s.add_development_dependency "logger"
  end
end
