# frozen_string_literal: true

require_relative 'lib/auto_increment/version'

Gem::Specification.new do |s|
  s.name        = 'auto_increment'
  s.version     = AutoIncrement::VERSION::STRING
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Felipe Diesel']
  s.email       = ['felipediesel@gmail.com']
  s.homepage    = 'https://github.com/jbox-web/auto_increment'
  s.summary     = 'Auto increment a string or integer field'
  s.description = 'Automaticaly increments a string or integer field in ActiveRecord.'
  s.license     = 'MIT'

  s.required_ruby_version = '>= 3.2.0'

  s.metadata = {
    'homepage_uri' => s.homepage,
    'source_code_uri' => s.homepage,
    'changelog_uri' => "#{s.homepage}/blob/master/CHANGELOG.md",
    'bug_tracker_uri' => "#{s.homepage}/issues",
    'rubygems_mfa_required' => 'true'
  }

  s.files = Dir['README.md', 'CHANGELOG.md', 'LICENSE', 'lib/**/*.rb']

  # activerecord + railties, not the whole of rails: the gem uses ActiveRecord and
  # Rails::Engine only. Depending on `rails` forced actionmailer, actioncable,
  # activestorage and actiontext — with their transitive trees and CVE surface —
  # onto every consumer, including apps that are not web apps at all.
  s.add_dependency 'activerecord', '>= 7.0'
  s.add_dependency 'railties', '>= 7.0'
  s.add_dependency 'zeitwerk'
end
