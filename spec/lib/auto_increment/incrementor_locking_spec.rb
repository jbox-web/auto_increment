# frozen_string_literal: true

require 'spec_helper'

# Locking is the one area where a green SQLite suite proves nothing: SQLite's Arel
# visitor silently DROPS lock clauses, so every example here passed on SQLite while
# PostgreSQL rejected the query outright. Run with DATABASE_ADAPTER=postgresql.
RSpec.describe AutoIncrement::Incrementor do
  describe 'lock: true on an integer column' do
    # The lock used to be applied to a `MAX()` query, which PostgreSQL refuses:
    # `FOR UPDATE is not allowed with aggregate functions`. The locked read must
    # therefore return a row, not an aggregate.
    it 'creates a record without the database rejecting the query' do
      expect { LockedSequence.create! }.not_to raise_error
    end

    it 'still increments from the existing maximum' do
      LockedSequence.create!(number: 7)
      expect(LockedSequence.create!.number).to eq 8
    end
  end

  describe 'lock: :advisory' do
    it 'creates a record' do
      expect { AdvisorySequence.create! }.not_to raise_error
    end

    it 'increments normally' do
      AdvisorySequence.create!(code: 'A')
      expect(AdvisorySequence.create!.code).to eq 'B'
    end

    # A transaction-scoped advisory lock taken with no transaction open is released
    # at once and serialises nothing. Reported on every adapter, not only where the
    # lock is real, because a silent no-op is the failure this mode exists to avoid.
    # `transaction_open?` is stubbed because DatabaseCleaner holds a transaction
    # open around every example, so the condition cannot occur for real here.
    it 'refuses to pretend when no transaction is open' do
      incrementor = described_class.new(:code, initial: 'A', lock: :advisory)
      allow(AdvisorySequence.connection).to receive(:transaction_open?).and_return(false)

      expect { incrementor.send(:advisory_lock!, AdvisorySequence.new) }
        .to raise_error(/requires an open transaction/)
    end
  end

  describe 'an unknown lock mode' do
    it 'is rejected instead of being read as truthy' do
      expect { described_class.new(:code, lock: 'yes') }
        .to raise_error(ArgumentError, /lock/)
    end
  end

  describe 'retrying a unique index violation' do
    # A unique index is what actually guarantees correctness; the retry is what
    # makes losing the race recoverable. Without clearing the column first, the
    # retry would reinsert the very value that just collided.
    before do
      RacySequence.lease_connection.execute(
        'CREATE UNIQUE INDEX idx_sequences_code_unique ON sequences (code)'
      )
      RacySequence.create!(code: 'A')
      # The seed record ran the callbacks too; zero the counter so `attempts`
      # measures only the attempts made by the example itself.
      RacySequence.attempts = 0
    end

    after do
      RacySequence.steal_times = 0
      RacySequence.attempts = 0
      RacySequence.lease_connection.execute('DROP INDEX IF EXISTS idx_sequences_code_unique')
    end

    it 'still persists the record when the first attempt is rejected' do
      RacySequence.steal_times = 1

      expect { RacySequence.create! }.not_to raise_error
    end

    it 'recomputes the value on a second attempt instead of reinserting the loser' do
      RacySequence.steal_times = 1
      RacySequence.create!

      expect(RacySequence.attempts).to eq 2
    end

    it 'gives up rather than looping when retrying cannot help' do
      RacySequence.steal_times = 99

      expect { RacySequence.create! }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'bounds the number of attempts' do
      RacySequence.steal_times = 99
      suppress(ActiveRecord::RecordNotUnique) { RacySequence.create! }

      expect(RacySequence.attempts).to eq AutoIncrement::Retryable::MAX_ATTEMPTS
    end
  end
end
