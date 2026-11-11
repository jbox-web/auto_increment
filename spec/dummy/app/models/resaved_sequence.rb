# frozen_string_literal: true

# `before: :save` plus `force: true` — the combination the README documents, and
# the one where the record used to feed on its own value: the callback runs on
# every update, the max query included the record itself, so each save returned
# `own value + 1` and the number climbed forever.
class ResavedSequence < ApplicationRecord
  self.table_name = 'sequences'

  auto_increment :number, before: :save, force: true
end
