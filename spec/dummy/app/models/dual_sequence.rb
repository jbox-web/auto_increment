# frozen_string_literal: true

# Two increments on one model. This is what exercises the second pass through the
# macro: the first call installs `auto_increment_columns` and prepends Retryable,
# the second must only append to the list — otherwise the retry would clear just
# one of the two columns and reinsert the value that collided in the other.
class DualSequence < ApplicationRecord
  self.table_name = 'sequences'

  auto_increment :code, initial: 'A'
  auto_increment :number
end
