# frozen_string_literal: true

module AutoIncrement
  module ActiveRecord

    # The lifecycle hooks an Incrementor can actually serve. It responds to
    # before_create / before_save / before_validation (the latter two aliased), so
    # anything else registers a callback object that cannot answer the message —
    # `before: :destroy` used to be accepted at load and fail later, at destroy
    # time, far from its cause.
    CALLBACKS = %i[create save validation].freeze

    # Class macro injected onto ActiveRecord::Base (via the engine). It registers
    # an Incrementor as the callback object for the chosen lifecycle hook: the
    # instance itself is what Rails invokes, so no method is defined on the model.
    #
    # It also prepends Retryable, which makes a unique index violation
    # recoverable. That retry is the real concurrency guarantee — see the module.
    def auto_increment(column = nil, options = {})
      options = options.reverse_merge(before: :create)

      unless CALLBACKS.include?(options[:before])
        raise ArgumentError, "auto_increment: unknown before: #{options[:before].inspect}, " \
                             "expected one of #{CALLBACKS.inspect}"
      end

      incrementor = Incrementor.new(column, options)
      register_auto_increment_column(incrementor.column)

      send "before_#{options[:before]}", incrementor
    end


    private


    # The retry has to know which columns to clear before trying again, and the
    # Incrementors are opaque callback objects by then — so the columns are
    # recorded on the model. `class_attribute` rather than a plain ivar so that a
    # subclass inherits its parent's columns and can add its own without mutating
    # the parent's array.
    def register_auto_increment_column(column)
      unless respond_to?(:auto_increment_columns)
        class_attribute :auto_increment_columns, instance_writer: false, default: []
        prepend Retryable
      end

      self.auto_increment_columns += [column]
    end

  end
end
