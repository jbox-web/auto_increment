class Account < ApplicationRecord
  auto_increment :code, before: :validation
  has_many :users
end
