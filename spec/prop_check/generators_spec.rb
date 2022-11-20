RSpec.describe PropCheck::Generators do
  describe '#dates' do
    subject(:dates) { described_class.dates }

    it 'produces valid dates' do
      PropCheck.forall(dates) do |date|
        expect(date).to be_a(Date)
      end
    end
  end

  describe '#times' do
    subject(:times) { described_class.times }

    it 'produces valid times' do
      PropCheck.forall(times) do |time|
        expect(time).to be_a(Time)
      end
    end
  end

  describe '#date_times' do
    subject(:date_times) { described_class.date_times }

    it 'produces valid date_times' do
      PropCheck.forall(date_times) do |date_time|
        expect(date_time).to be_a(DateTime)
      end
    end
  end
end
