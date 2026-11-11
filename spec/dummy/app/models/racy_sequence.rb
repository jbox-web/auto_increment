# frozen_string_literal: true

# Drives the retry deterministically. `steal_times` is how many attempts should
# have their freshly computed value occupied by another row before this record
# reaches the database; `attempts` counts how many times the create callbacks ran,
# which is what makes the retry observable.
#
# Scope note: the thief inserts inside the savepoint that AutoIncrement::Retryable
# opened, so rolling that attempt back also removes the stolen row. This therefore
# exercises the retry loop, the savepoint and the attempt bound — but NOT recovery
# from a competitor that has already committed, which would need a second
# connection and would leak rows past the example's transaction.
class RacySequence < ApplicationRecord
  self.table_name = 'sequences'

  cattr_accessor :steal_times, default: 0
  cattr_accessor :attempts, default: 0

  auto_increment :code, initial: 'A'

  # Declared AFTER the macro on purpose: before_create callbacks run in
  # declaration order, so this one sees the value the incrementor just computed
  # and can occupy it, forcing the unique index to reject this record's insert.
  before_create :steal_computed_value

  private

  def steal_computed_value
    self.class.attempts += 1
    return if self.class.steal_times.zero?

    self.class.steal_times -= 1
    self.class.unscoped.insert_all([{ code: read_attribute(:code) }])
  end
end
