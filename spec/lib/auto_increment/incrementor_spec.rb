# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AutoIncrement::Incrementor do
  {
    nil => 1,
    0 => 1,
    1 => 2,
    'A' => 'B',
    'Z' => 'AA',
    'AA' => 'AB',
    'AAAAA' => 'AAAAB'
  }.each do |previous_value, next_value|
    describe "increment value for #{previous_value}" do
      it do
        allow(subject).to receive(:maximum) { previous_value } # rubocop:disable RSpec/SubjectStub, RSpec/NamedSubject
        expect(subject.send(:increment, nil)).to eq next_value # rubocop:disable RSpec/NamedSubject
      end
    end
  end

  describe 'initial value of string' do
    subject(:incrementor) { described_class.new initial: 'A' }

    it do
      allow(incrementor).to receive(:maximum).and_return(nil) # rubocop:disable RSpec/SubjectStub
      expect(incrementor.send(:increment, nil)).to eq 'A'
    end
  end

  # The Incrementor is registered once as a callback object and is therefore
  # SHARED by every record of the model, across threads. It must keep no
  # per-record state: a retained @record is read by build_scopes/maximum, so a
  # second record entering the callback (e.g. another thread during the MAX
  # query, a GIL yield point) makes the first compute against the wrong scope.
  describe 'record isolation (shared callback object)' do
    subject(:incrementor) { described_class.new(:code) }

    it 'retains no per-record state after the callback' do
      allow(incrementor).to receive(:maximum).and_return(0) # rubocop:disable RSpec/SubjectStub

      incrementor.before_create(Account.new)

      expect(incrementor.instance_variable_get(:@record)).to be_nil
    end
  end

  # `lock: true` must apply SELECT ... FOR UPDATE to the relation that is
  # actually queried. `Relation#lock` returns a NEW relation, so its result
  # must be kept, not discarded.
  describe 'lock option' do
    subject(:incrementor) { described_class.new(:code, lock: true) }

    it 'queries the locked relation, not an unlocked copy' do # rubocop:disable RSpec/ExampleLength
      base   = instance_double(ActiveRecord::Relation)
      locked = instance_double(ActiveRecord::Relation)

      allow(incrementor).to receive_messages(build_model_scope: base, build_scopes: base) # rubocop:disable RSpec/SubjectStub
      allow(base).to receive_messages(lock: locked, maximum: 99) # 99 = unlocked path (wrong)
      allow(locked).to receive(:maximum).and_return(3)           # 3  = locked path (correct)

      record = Account.new
      incrementor.before_create(record)

      expect(record.code).to eq 4
    end
  end

  # `scope` and `model_scope` accept either a single value or an Array. A single
  # value is wrapped into a one-element Array; an Array is kept verbatim so that
  # multiple entries are honored.
  describe 'scope option normalization' do
    it 'wraps a single scope value into an Array' do
      incrementor = described_class.new(:code, scope: :account_id, model_scope: :with_mark)

      expect(incrementor.instance_variable_get(:@options)[:scope]).to eq [:account_id]
      expect(incrementor.instance_variable_get(:@options)[:model_scope]).to eq [:with_mark]
    end

    it 'keeps an Array scope verbatim' do
      incrementor = described_class.new(:code, scope: %i[account_id kind], model_scope: %i[with_mark active])

      expect(incrementor.instance_variable_get(:@options)[:scope]).to eq %i[account_id kind]
      expect(incrementor.instance_variable_get(:@options)[:model_scope]).to eq %i[with_mark active]
    end
  end
end
