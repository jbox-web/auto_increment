# frozen_string_literal: true

module AutoIncrement
  # Everything the Incrementor knows about serialising concurrent increments.
  #
  # None of it is the actual guarantee: reading the maximum and adding one is never
  # atomic, so correctness comes from a unique index plus the retry in
  # AutoIncrement::Retryable. These modes only reduce how often that retry fires.
  module Locking

    # `false` — no locking.
    # `true`  — lock the row holding the current maximum. Partial by construction:
    #   `FOR UPDATE` locks the rows it returns, so an empty scope locks nothing and
    #   two concurrent first inserts both compute `initial`.
    # `:advisory` — PostgreSQL transaction-scoped advisory lock, which does cover
    #   the empty scope because it is a named mutex rather than a row lock.
    LOCK_MODES = [false, true, :advisory].freeze

    private

    # Left unvalidated, any truthy value silently selected row locking — so a
    # misspelt `lock: :advisiory` quietly gave a weaker guarantee than the one asked
    # for, which is the opposite of what the option exists for.
    def validate_lock_mode!
      return if LOCK_MODES.include?(@options[:lock])

      raise ArgumentError, "auto_increment: unknown lock mode #{@options[:lock].inspect}, " \
                           "expected one of #{LOCK_MODES.inspect}"
    end


    def row_lock?
      @options[:lock] == true
    end


    def advisory?
      @options[:lock] == :advisory
    end


    # Taken before the maximum is read and held until the OUTERMOST transaction
    # commits — not until the query returns. A caller wrapping many creates in one
    # transaction therefore serialises every other writer on the same key for the
    # whole block; that is the price of the guarantee, and the reason this is opt-in.
    #
    # A no-op outside PostgreSQL, and deliberately not an error: SQLite serialises
    # writers on its own, and MySQL's nearest equivalent (`GET_LOCK`) is
    # session-scoped rather than transaction-scoped, so it would survive the commit
    # and leak. Raising would break the suite of any consumer that runs its own
    # specs on SQLite.
    def advisory_lock!(record)
      return unless advisory?

      connection = record.class.connection

      # Checked before the adapter, because the requirement belongs to the mode and
      # not to the backend: an advisory lock taken outside a transaction is released
      # immediately, i.e. it serialises nothing. Rails runs before_create inside the
      # save transaction, so this should never fire in normal use — but a silent
      # no-op here is exactly the failure this option exists to prevent, so it is
      # reported on every adapter rather than only where the lock is real.
      unless connection.transaction_open?
        raise 'auto_increment: lock: :advisory requires an open transaction, none is active'
      end

      return unless connection.adapter_name.match?(/postgres/i)

      connection.execute("SELECT pg_advisory_xact_lock(#{advisory_key(record)})")
    end


    # SHA-256 rather than String#hash: `hash` is seeded per process (verified —
    # three processes gave three different values for the same string), so two
    # workers would take two different locks and serialise nothing at all.
    #
    # The scope values belong in the key so the lock is per-scope; keyed on table
    # and column alone it would serialise every insert on the model.
    def advisory_key(record)
      parts = [record.class.table_name, @column.to_s]
      parts += @options[:scope].select(&:present?).map { |scope| record.send(scope).inspect }

      # NUL as the separator, not a space: otherwise table 'a b' + column 'c' and
      # table 'a' + column 'b c' would hash to the same key.
      Digest::SHA256.digest(parts.join(0.chr))[0, 8].unpack1('q>')
    end

  end
end
