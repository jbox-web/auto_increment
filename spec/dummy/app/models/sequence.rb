# frozen_string_literal: true

# Neutral fixture for the string path: a string column with a String `initial`,
# no default_scope, no model_scope. Any behavior observed here is the
# incrementor's own, not an interaction with the model.
class Sequence < ApplicationRecord
  auto_increment :code, initial: 'A'
end
