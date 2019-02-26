# frozen_string_literal: true

require 'zeitwerk'
Zeitwerk::Loader.for_gem.setup

module AutoIncrement
  require 'auto_increment/engine' if defined?(Rails)
end
