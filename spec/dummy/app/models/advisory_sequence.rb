# frozen_string_literal: true

# `lock: :advisory` — a transaction-scoped named mutex rather than a row lock.
# It is the only mode that also covers an empty scope, where a row lock has
# nothing to lock and two concurrent first inserts both compute `initial`.
class AdvisorySequence < ApplicationRecord
  self.table_name = 'sequences'

  auto_increment :code, initial: 'A', lock: :advisory
end
