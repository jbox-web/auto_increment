# frozen_string_literal: true

# A string column declared WITHOUT `initial:`, i.e. exactly what the README's
# basic example produces on a varchar column. The default `initial` is the
# Integer 1, so this is the configuration that used to select the integer path
# on a string column.
class PlainSequence < ApplicationRecord
  self.table_name = 'sequences'

  auto_increment :code
end
