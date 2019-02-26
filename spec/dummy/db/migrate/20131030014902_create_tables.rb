class CreateTables < ActiveRecord::Migration[4.2]
  def up
    create_table :accounts do |t|
      t.string  :name
      t.integer :code
    end

    create_table :users do |t|
      t.string  :name
      t.integer :account_id
      t.string  :letter_code
    end
  end
end
