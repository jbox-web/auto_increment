# frozen_string_literal: true

# require external dependencies
require 'digest'
require 'zeitwerk'

# load zeitwerk
Zeitwerk::Loader.for_gem.setup

module AutoIncrement
  require_relative 'auto_increment/engine' if defined?(Rails)
end
