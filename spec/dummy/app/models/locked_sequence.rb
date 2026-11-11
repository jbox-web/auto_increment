# frozen_string_literal: true

# An INTEGER column with `lock: true`. This is the configuration that used to
# make PostgreSQL reject every create: the lock was applied to a `MAX()` query,
# and `FOR UPDATE is not allowed with aggregate functions`.
class LockedSequence < ApplicationRecord
  self.table_name = 'sequences'

  auto_increment :number, lock: true
end
