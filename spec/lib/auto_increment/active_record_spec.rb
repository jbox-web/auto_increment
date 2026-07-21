# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AutoIncrement::ActiveRecord do
  before :all do # rubocop:disable RSpec/BeforeAfterAll
    @account1 = Account.create name: 'My Account'
    @account2 = Account.create name: 'Another Account', code: 50

    @user1_account1 = @account1.users.create name: 'Felipe', letter_code: 'Z'
    @user1_account2 = @account2.users.create name: 'Daniel'
    @user2_account2 = @account2.users.create name: 'Mark'
    @user3_account2 = @account2.users.create name: 'Robert'
  end

  describe 'initial' do
    it { expect(@account1.code).to eq 1 }
    it { expect(@user1_account1.letter_code).to eq 'A' }
  end

  describe 'do not increment outside scope' do
    it { expect(@user1_account2.letter_code).to eq 'A' }
  end

  describe 'not set column if is already set' do
    it { expect(@account2.code).to eq 50 }
  end

  describe 'set column if option force is used' do
    it { expect(@user1_account1.letter_code).to eq 'A' }
  end

  # NOTE: SQLite serializes writers, so true concurrency can't be exercised
  # reliably here; the isolation/lock guarantees are covered deterministically in
  # incrementor_spec. This checks the increment stays gapless and duplicate-free
  # within a scope. (The previous version wrapped every thread in a Mutex, which
  # serialized all work and so never tested concurrency at all.)
  describe 'increments without gaps or duplicates within a scope' do
    before :all do # rubocop:disable RSpec/BeforeAfterAll
      @account = Account.create name: 'Sequenced Account', code: 50
      @accounts = Array.new(25) { @account.users.create name: 'Daniel' }
    end

    let(:letter_codes) { @accounts.map(&:letter_code) }

    it { expect(@accounts.size).to eq 25 }
    it { expect(letter_codes.uniq.size).to eq 25 }
    it { expect(letter_codes.max).to eq 'Y' }
  end

  describe 'set before validation' do
    let(:account3) do
      account3 = Account.new
      account3.valid?
      account3
    end

    it { expect(account3.code).not_to be_nil }
  end

  describe 'uses model scopes' do
    it { expect(@user3_account2.letter_code).to eq('C') }
  end
end
