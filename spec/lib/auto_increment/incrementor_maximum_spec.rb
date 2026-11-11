# frozen_string_literal: true

require 'spec_helper'

# These examples run the real max query against the real database instead of
# stubbing `maximum`. That distinction is the whole point: every defect in this
# file is invisible to a stubbed relation, and several of them are invisible on
# SQLite too. Run the suite with DATABASE_ADAPTER=postgresql as well.
RSpec.describe AutoIncrement::Incrementor do
  describe 'the string path with a NULL already in the column' do
    # `ORDER BY LENGTH(col) DESC, col DESC` does not order NULLs the same way on
    # every adapter: PostgreSQL sorts them first, SQLite last. When they come
    # first, `.first` returns the NULL row, the max reads as nil, and every
    # subsequent record silently restarts at `initial` — unlimited duplicates.
    before do
      Sequence.create!(code: 'A')
      Sequence.insert_all([{ code: nil }])
    end

    it 'keeps incrementing from the real maximum' do
      expect(Sequence.create!.code).to eq 'B'
    end

    it 'does not reissue a value that already exists' do
      Sequence.create!
      expect(Sequence.where(code: 'A').count).to eq 1
    end
  end

  describe 'a string column declared without an explicit initial' do
    # SQL MAX over a varchar is plain lexicographic, so 'Z' outranks 'AA' and the
    # maximum stops advancing at the first carry: the sequence emits 'AA'
    # forever. The value type must therefore follow the column, not `initial`.
    before { PlainSequence.create!(code: 'Y') }

    it 'keeps advancing past the carry instead of repeating it' do
      3.times { PlainSequence.create! }
      expect(PlainSequence.pluck(:code)).to eq %w[Y Z AA AB]
    end

    it 'issues no duplicate across the carry' do
      3.times { PlainSequence.create! }
      expect(PlainSequence.pluck(:code).uniq.size).to eq 4
    end
  end

  describe 'a model whose default_scope hides part of its own table' do
    # The max query must not inherit the default scope: a hidden row still
    # occupies its value in the sequence, so a scope that filters it out makes the
    # incrementor reissue a value that is already taken — silently.
    # The hidden row is inserted through `unscoped` deliberately. An equality
    # default_scope also supplies attributes for creation, and Rails applies them
    # in `insert_all` too — `ScopedSequence.insert_all(scope_id: 1)` would come
    # back with scope_id nil, i.e. a row that is not hidden at all and a spec that
    # proves nothing.
    before do
      ScopedSequence.create!(code: 'A')
      ScopedSequence.unscoped.insert_all([{ code: 'B', scope_id: 1 }])
    end

    it 'counts the rows the model itself cannot see' do
      expect(ScopedSequence.create!.code).to eq 'C'
    end

    it 'reissues no value that a hidden row already holds' do
      ScopedSequence.create!
      expect(ScopedSequence.unscoped.pluck(:code).uniq.size).to eq 3
    end
  end

  describe 'a record saved again under before: :save with force: true' do
    # The max query must exclude the record being saved. Included, the record reads
    # its own value as the maximum and every update returns own value + 1, so an
    # untouched attribute drifts upwards on each save.
    subject(:record) { ResavedSequence.create!(code: 'seed') }

    it 'keeps the same value across repeated saves' do
      first = record.number
      3.times { |i| record.update!(code: "seed#{i}") }

      expect(record.number).to eq first
    end

    it 'still advances for the next record' do
      record
      expect(ResavedSequence.create!(code: 'other').number).to eq record.number + 1
    end
  end

  describe 'a model that overrides the reader of the incremented column' do
    # The write goes through write_attribute, so the blank check must go through
    # read_attribute. Read through the override, the value is never blank, the
    # incrementor declines to write, and the column is persisted NULL.
    it 'writes the raw attribute anyway' do
      expect(OverriddenSequence.create!.read_attribute(:code)).to eq 'A'
    end

    it 'keeps incrementing from the raw values' do
      OverriddenSequence.create!
      expect(OverriddenSequence.create!.read_attribute(:code)).to eq 'B'
    end
  end
end
