# frozen_string_literal: true

require 'zeitwerk'
loader = Zeitwerk::Loader.for_gem
loader.setup

module AutoIncrement
  require 'auto_increment/engine' if defined?(Rails)
end
