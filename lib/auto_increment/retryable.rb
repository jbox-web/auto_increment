# frozen_string_literal: true

module AutoIncrement
  # Prepended onto every model that declares `auto_increment`. It turns a unique
  # index violation into a bounded retry, and that retry — not a lock — is what
  # actually makes concurrent inserts safe.
  #
  # Why a lock cannot be the mechanism: reading the maximum and adding one is
  # never atomic, and `SELECT ... FOR UPDATE` locks the rows it *returns*. On an
  # empty scope it returns nothing, locks nothing, and two concurrent first
  # inserts both compute `initial`. A unique index has no such hole.
  #
  # The gem cannot create that index. Without one there is nothing to retry on and
  # concurrent inserts can still collide — see the README.
  module Retryable

    # Each attempt re-reads the maximum, so a bounded count is enough to survive
    # ordinary contention. The bound also matters for a violation this gem cannot
    # fix (a unique index on some other column): it surfaces after N attempts
    # instead of looping.
    MAX_ATTEMPTS = 3

    private

    # The SAVEPOINT is not a precaution. Verified on PostgreSQL 18: a unique
    # violation inside a caller-owned transaction leaves it aborted
    # (`PG::InFailedSqlTransaction: current transaction is aborted, commands
    # ignored until end of transaction`), so every later statement — the retry
    # included — fails. `requires_new: true` gives each attempt its own savepoint,
    # which can be rolled back alone. SQLite tolerates the retry without one, but
    # the behavior must not depend on the adapter.
    #
    # The cost is one SAVEPOINT/RELEASE per create, paid by every consumer.
    def _create_record(*)
      attempts = 0

      begin
        attempts += 1
        self.class.transaction(requires_new: true) { super }
      rescue ::ActiveRecord::RecordNotUnique
        raise if attempts >= MAX_ATTEMPTS

        clear_auto_increment_columns
        retry
      end
    end


    # Without this the retry is pointless: the column still holds the value that
    # just collided, so `can_write?` sees it as present, declines to recompute, and
    # every attempt reinserts the same losing value.
    def clear_auto_increment_columns
      self.class.auto_increment_columns.each { |column| write_attribute(column, nil) }
    end

  end
end
