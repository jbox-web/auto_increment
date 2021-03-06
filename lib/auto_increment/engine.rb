# frozen_string_literal: true

module AutoIncrement
  class Engine < ::Rails::Engine

    initializer 'auto_increment.initialize' do
      ActiveSupport.on_load(:active_record) do
        extend AutoIncrement::ActiveRecord
      end
    end

  end
end
