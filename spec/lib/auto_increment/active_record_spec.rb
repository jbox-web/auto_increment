# frozen_string_literal: true

require 'spec_helper'

# Everything here is set up per example with `let!`, never in `before(:all)`.
# DatabaseCleaner wraps each example in a transaction, but a `before(:all)` block
# runs outside it: those rows survived the example, the file and the whole run —
# measured, 3 accounts and 29 users still in the test database after a clean pass.
# With `config.order = :random` that turns into order-dependent coupling, since any
# group persisting an Account first would shift the values this file asserts on.
RSpec.describe AutoIncrement::ActiveRecord do
  let!(:fresh_account) { Account.create! name: 'My Account' }
  let!(:preset_account) { Account.create! name: 'Another Account', code: 50 }

  describe 'initial' do
    it { expect(fresh_account.code).to eq 1 }
  end

  describe 'not set column if is already set' do
    it { expect(preset_account.code).to eq 50 }
  end

  describe 'set before validation' do
    let(:unsaved_account) do
      account = Account.new
      account.valid?
      account
    end

    it { expect(unsaved_account.code).not_to be_nil }
  end

  describe 'scoped increments on User' do
    let!(:felipe) { fresh_account.users.create! name: 'Felipe', letter_code: 'Z' }
    # Created in one go so the order — and therefore the expected sequence — is
    # unambiguous: Daniel, then Mark, then Robert.
    let!(:colleagues) do
      %w[Daniel Mark Robert].map { |name| preset_account.users.create!(name: name) }
    end

    describe 'initial' do
      # force: true, so the supplied 'Z' is overwritten with the computed initial.
      it { expect(felipe.letter_code).to eq 'A' }
    end

    describe 'do not increment outside scope' do
      it { expect(colleagues.first.letter_code).to eq 'A' }
    end

    describe 'uses model scopes' do
      # model_scope: :with_mark is `unscoped`, so the row hidden by User's
      # default_scope (Mark) still counts: Daniel A, Mark B, Robert C.
      it { expect(colleagues.map(&:letter_code)).to eq %w[A B C] }
    end
  end

  # NOTE: SQLite serializes writers, so true concurrency can't be exercised
  # reliably here; the isolation and locking guarantees are covered
  # deterministically in incrementor_spec and incrementor_locking_spec. This checks
  # the increment stays gapless and duplicate-free within a scope.
  describe 'increments without gaps or duplicates within a scope' do
    let!(:sequenced_account) { Account.create! name: 'Sequenced Account', code: 50 }
    let(:letter_codes) do
      Array.new(25) { sequenced_account.users.create!(name: 'Daniel') }.map(&:letter_code)
    end

    it { expect(letter_codes.size).to eq 25 }
    it { expect(letter_codes.uniq.size).to eq 25 }
    it { expect(letter_codes.max).to eq 'Y' }
  end

  # Two increments on one model: the macro must register both columns so the retry
  # in AutoIncrement::Retryable clears every one of them before trying again.
  describe 'two auto_increment columns on the same model' do
    it 'registers both columns' do
      expect(DualSequence.auto_increment_columns).to eq %i[code number]
    end

    it 'fills both' do
      record = DualSequence.create!
      expect([record.code, record.number]).to eq ['A', 1]
    end
  end
end
