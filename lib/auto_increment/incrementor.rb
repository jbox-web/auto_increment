# frozen_string_literal: true

module AutoIncrement
  class Incrementor

    def initialize(column = nil, options = {})
      if column.is_a?(Hash)
        options = column
        column = nil
      end

      @column  = column || options[:column] || :code
      @options = options.reverse_merge(initial: 1, force: false)

      @options[:scope]       = [@options[:scope]]       unless @options[:scope].is_a?(Array)
      @options[:model_scope] = [@options[:model_scope]] unless @options[:model_scope].is_a?(Array)
    end


    def before_create(record)
      @record = record
      write if can_write?
    end

    alias before_validation before_create
    alias before_save before_create


    private


    def write
      @record.send(:write_attribute, @column, increment)
    end


    def can_write?
      @record.send(@column).blank? || @options[:force]
    end


    def increment
      max = maximum
      max.blank? ? @options[:initial] : max.next
    end


    def maximum
      query = build_scopes(build_model_scope(@record.class))
      query.lock if lock?

      if string?
        query.select("#{@column} max")
             .order(Arel.sql("LENGTH(#{@column}) DESC, #{@column} DESC"))
             .first.try(:max)
      else
        query.maximum(@column)
      end
    end


    def build_scopes(query)
      @options[:scope].each do |scope|
        query = query.where(scope => @record.send(scope)) if scope.present? && @record.respond_to?(scope)
      end

      query
    end


    def build_model_scope(query)
      @options[:model_scope].compact.each do |scope|
        query = query.send(scope)
      end

      query
    end


    def lock?
      @options[:lock] == true
    end


    def string?
      @options[:initial].is_a?(String)
    end

  end
end
