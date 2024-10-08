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
        expect(subject.send(:increment)).to eq next_value # rubocop:disable RSpec/NamedSubject
      end
    end
  end

  describe 'initial value of string' do
    subject(:incrementor) { described_class.new initial: 'A' }

    it do
      allow(incrementor).to receive(:maximum).and_return(nil) # rubocop:disable RSpec/SubjectStub
      expect(incrementor.send(:increment)).to eq 'A'
    end
  end
end
