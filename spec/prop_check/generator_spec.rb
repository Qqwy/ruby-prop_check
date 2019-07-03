require 'doctest/rspec'


RSpec.describe PropCheck::Generator do
  Generator = PropCheck::Generator
  Generators = PropCheck::Generators
  doctest PropCheck::Generator
  doctest PropCheck::Generators

  xdescribe "#where" do
    it "filters out results we do not like" do
      no_fizzbuzz = PropCheck::Generators.integer.where { |val| val % 3 != 0 && val % 5 != 0 }
      PropCheck::forall(num: no_fizzbuzz) do
        expect(num).to_not be(3)
        expect(num).to_not be(5)
        expect(num).to_not be(6)
        expect(num).to_not be(9)
        expect(num).to_not be(10)
        expect(num).to_not be(15)
      end
    end

    it "might cause a Generator Exhaustion if we filter too much" do
      never = PropCheck::Generators.nil.where { |val| val != nil }
      expect do
        PropCheck::forall(thing: never) do
          true
        end
      end.to raise_error do |error|
        expect(error).to be_a(PropCheck::GeneratorExhaustedError)
      end
    end
  end
end
