# frozen_string_literal: true

module AutoIncrement
  class Incrementor

    include Locking

    # Column types whose maximum must be computed with the string strategy.
    STRING_COLUMN_TYPES = %i[string text].freeze

    attr_reader :column

    def initialize(column = nil, options = {})
      if column.is_a?(Hash)
        options = column
        column = nil
      end

      @column  = column || options[:column] || :code
      @options = options.reverse_merge(initial: 1, force: false, lock: false)

      normalize_scopes!
      validate_lock_mode!
    end


    # This Incrementor instance is registered once as a callback object and is
    # therefore SHARED by every record of the model, across threads. It must
    # keep no per-record state — the record is threaded through as an argument.
    def before_create(record)
      write(record) if can_write?(record)
    end

    alias before_validation before_create
    alias before_save before_create


    private


    # Both options accept a single value or an Array; a single value is wrapped so
    # the rest of the class only ever iterates.
    def normalize_scopes!
      @options[:scope]       = [@options[:scope]]       unless @options[:scope].is_a?(Array)
      @options[:model_scope] = [@options[:model_scope]] unless @options[:model_scope].is_a?(Array)
    end


    # `write_attribute` is public, so there is nothing to reach around with `send`.
    def write(record)
      record.write_attribute(@column, increment(record))
    end


    # Reads the RAW attribute, symmetrically with `write`. Reading through the
    # public accessor let a model that overrides the reader break the gem silently:
    # the override returns something non-blank, the blank check therefore declines
    # to write, and the column is persisted NULL with no error anywhere.
    def can_write?(record)
      record.read_attribute(@column).blank? || @options[:force]
    end


    # `.next` is polymorphic: Integer#next adds one, String#next advances
    # lexicographically with carry ('Z' => 'AA'). An empty table falls back to
    # `initial`.
    def increment(record)
      max = maximum(record)
      max.blank? ? @options[:initial] : max.next
    end


    # The base relation is `unscoped`, NOT the model: a default_scope that hides
    # part of the table (soft delete, single-tenant) would otherwise hide rows
    # that still occupy values in the sequence, and the next value would silently
    # duplicate one of them. `scope:` and `model_scope:` remain the way to narrow
    # the query deliberately.
    #
    # `unscoped` and not `unscope(:where)`: verified that `unscoped` drops the
    # default scope while KEEPING the STI type condition, whereas `unscope(:where)`
    # drops both — which would make the maximum span every sibling subclass.
    def maximum(record)
      advisory_lock!(record)

      query = build_scopes(build_model_scope(record.class.unscoped), record)
      query = exclude_self(query, record)
      # Relation#lock returns a NEW relation, so its result must be kept.
      query = query.lock if row_lock?

      string?(record) ? string_maximum(query, record) : integer_maximum(query)
    end


    # A record must never be its own maximum. With `before: :save` (which also runs
    # on updates) and `force: true`, the record read the value it already holds and
    # returned it plus one, so an untouched attribute climbed on every save —
    # measured 3, 4, 5, 6 over one create and three updates.
    #
    # Only meaningful once the row exists; on create there is nothing to exclude.
    # Guarded on `primary_key` because a model declared without one has no id to
    # filter on.
    def exclude_self(query, record)
      return query unless record.persisted? && record.class.primary_key

      query.where.not(record.class.primary_key => record.id)
    end


    # Reads the top row rather than an aggregate when a row lock is in play:
    # PostgreSQL rejects `SELECT MAX(col) ... FOR UPDATE` outright with
    # `FOR UPDATE is not allowed with aggregate functions`, so the previous
    # `MAX()` form made every create fail there. `pick` yields nil on an empty
    # relation, exactly like `maximum`.
    def integer_maximum(query)
      return query.order(@column => :desc).limit(1).pick(@column) if row_lock?

      query.maximum(@column)
    end


    # String columns can't use SQL MAX: lexicographically 'Z' outranks 'AA', yet
    # 'AA' is the real successor (see String#next in `increment`). Ordering by
    # LENGTH first, then value, yields the true maximum of that sequence.
    #
    # NULLs MUST be excluded explicitly. Adapters disagree on where they sort:
    # PostgreSQL places them first under DESC, SQLite last. Left in, a single NULL
    # row makes `.first` return it, the maximum read as nil, and every later
    # record restart at `initial` — silent, unlimited duplicates, on PostgreSQL
    # only. SQL MAX on the integer path skips NULLs by itself, so the asymmetry
    # between the two paths is real and not a redundancy.
    def string_maximum(query, record)
      column = record.class.connection.quote_column_name(@column)

      query.where.not(@column => nil)
           .select("#{column} max")
           .order(Arel.sql("LENGTH(#{column}) DESC, #{column} DESC"))
           .first.try(:max)
    end


    # A scope the record cannot answer to is an error, never a no-op. Skipping it
    # silently turned a per-scope sequence into a table-wide one, so a typo or a
    # renamed column produced wrong values with nothing raised anywhere.
    #
    # The check is here rather than in the macro on purpose: at class-definition
    # time the table may not exist yet, so validating column names at boot would
    # break `db:migrate` on a fresh database.
    def build_scopes(query, record)
      @options[:scope].select(&:present?).each do |scope|
        unless record.respond_to?(scope)
          raise ArgumentError, "auto_increment: #{record.class} does not respond to scope #{scope.inspect}"
        end

        query = query.where(scope => record.send(scope))
      end

      query
    end


    def build_model_scope(query)
      @options[:model_scope].compact.each do |scope|
        validate_model_scope!(query.klass, scope)
        query = query.public_send(scope)
      end

      query
    end


    # `send` reached private methods and, worse, every Relation method Rails
    # delegates onto the model: `model_scope: :delete_all` emptied the table on
    # every create (verified — the call returned the deleted row count, which then
    # received `.maximum`).
    #
    # The filter: a named scope is defined on the model's own singleton class,
    # whereas the delegated query methods are owned by ActiveRecord::Querying. This
    # is a heuristic and not a registry — Rails exposes no list of scope names — but
    # it separates the two cases that matter.
    def validate_model_scope!(model, scope)
      owner = begin
        model.singleton_class.instance_method(scope).owner
      rescue NameError
        raise ArgumentError, "auto_increment: model_scope #{scope.inspect} is not defined on #{model}"
      end

      return unless owner.name.to_s.start_with?('ActiveRecord')

      raise ArgumentError, "auto_increment: model_scope #{scope.inspect} is not a scope on " \
                           "#{model}, it is #{owner}##{scope}"
    end


    # Selects the string path (length-then-value max + String#next) over the
    # integer path (SQL MAXIMUM). A String `initial` OR a string/text column both
    # select it, and the union is deliberate:
    #
    # - The column alone is not enough. An integer column with a String
    #   `initial` used to take the string path and work; inferring only from the
    #   column would send it to the integer path, seed it with a String, and
    #   silently persist 0.
    # - `initial` alone is not enough either, and this was the actual defect: a
    #   string column left with the default integer `initial` took the integer
    #   path, i.e. SQL MAX over a varchar. That comparison is plain
    #   lexicographic, so 'Z' outranks 'AA' and the maximum stops advancing at
    #   the first carry — the sequence then emits 'AA' forever. Measured:
    #   seeding 'Y' produced Z, AA, AA, AA. It was never "numeric", as an earlier
    #   comment here claimed.
    def string?(record)
      return true if @options[:initial].is_a?(String)

      STRING_COLUMN_TYPES.include?(record.class.type_for_attribute(@column).type)
    end

  end
end
