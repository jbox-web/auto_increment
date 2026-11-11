# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

# Dev libs
gem 'appraisal', git: 'https://github.com/thoughtbot/appraisal.git'
gem 'database_cleaner'
gem 'pg'
# The gem itself only depends on activerecord + railties; the dummy app under
# spec/dummy does `require "rails/all"`, so the full framework is a DEV dependency.
gem 'rails'
gem 'rake'
gem 'rspec-rails'
gem 'simplecov'
gem 'sqlite3', '~> 2.1.0'

# Dev tools / linter
gem 'guard-rspec',         require: false
gem 'rubocop',             require: false
gem 'rubocop-performance', require: false
gem 'rubocop-rake',        require: false
gem 'rubocop-rspec',       require: false
gem 'rubocop-rspec_rails', require: false
