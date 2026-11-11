# frozen_string_literal: true

# A model whose default_scope hides part of its own table — the shape of every
# soft-delete (paranoia, discard) and single-tenant setup. Rows carrying a
# scope_id stand for the hidden ones; they still occupy values in the sequence,
# so the maximum must see them even though the model does not.
class ScopedSequence < ApplicationRecord
  self.table_name = 'sequences'

  default_scope -> { where(scope_id: nil) }

  auto_increment :code, initial: 'A'
end
