# frozen_string_literal: true

# require external dependencies
require 'zeitwerk'

# load zeitwerk
Zeitwerk::Loader.for_gem.tap do |loader| # rubocop:disable Style/SymbolProc
  loader.setup
end

module AutoIncrement
  require_relative 'auto_increment/engine' if defined?(Rails)
end
