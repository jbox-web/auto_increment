# frozen_string_literal: true

module AutoIncrement
  module ActiveRecord

    # Class macro injected onto ActiveRecord::Base (via the engine). It registers
    # an Incrementor as the callback object for the chosen lifecycle hook. The
    # Incrementor responds to before_create / before_save / before_validation
    # (the latter two aliased), so the instance itself is what Rails invokes — no
    # separate callback method is defined on the model.
    def auto_increment(column = nil, options = {})
      options = options.reverse_merge(before: :create)
      callback = "before_#{options[:before]}"
      send callback, Incrementor.new(column, options)
    end

  end
end
