# frozen_string_literal: true

RSpec.describe PropCheck::Generators do
  describe '#date' do
    subject(:date) { described_class.date }

    it 'produces valid dates' do
      PropCheck.forall(date) do |val|
        expect(val).to be_a(Date)
      end
    end
  end

  describe '#time' do
    subject(:time) { described_class.time }

    it 'produces valid times' do
      PropCheck.forall(time) do |val|
        expect(val).to be_a(Time)
      end
    end
  end

  describe '#date_time' do
    subject(:date_time) { described_class.date_time }

    it 'produces valid date_times' do
      PropCheck.forall(date_time) do |val|
        expect(val).to be_a(DateTime)
      end
    end
  end

  describe '#array' do
    it 'produces array that respect the min property' do
      n_int = described_class.nonnegative_integer
      PropCheck.forall(n_int) do |val|
        val += 1 if val == 0

        result = described_class.array(
          n_int,
          min: val,
          empty: false
        ).sample

        expect(result).to all have_attributes(length: (a_value >= val))
      end
    end
  end
end
