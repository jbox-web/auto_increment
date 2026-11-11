# frozen_string_literal: true

# A model that overrides the reader of the incremented column — presenting a
# formatted value, say. The incrementor writes the raw attribute, so it must also
# READ the raw attribute: reading through the override made it see a value that is
# never blank, so it declined to write and the column stayed NULL, silently.
class OverriddenSequence < ApplicationRecord
  self.table_name = 'sequences'

  auto_increment :code, initial: 'A'

  def code
    "formatted-#{read_attribute(:code)}"
  end
end
