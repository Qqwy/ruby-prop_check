require 'doctest/rspec'


RSpec.describe PropCheck::Generator do
  Generator = PropCheck::Generator
  Generators = PropCheck::Generators
  doctest PropCheck::Generator

  # Used in a PropCheck::Generators doctest
  class User
    def initialize(name: , age: )
      @name = name
      @age = age
    end

    def inspect
      "<User name: #{@name.inspect}, age: #{@age.inspect}>"
    end
  end
  doctest PropCheck::Generators

  describe "#where" do
    it "filters out results we do not like" do
      no_fizzbuzz = PropCheck::Generators.integer.where { |val| val % 3 != 0 && val % 5 != 0 }
      PropCheck::forall(num: no_fizzbuzz) do |num:|
        expect(num).to_not be(3)
        expect(num).to_not be(5)
        expect(num).to_not be(6)
        expect(num).to_not be(9)
        expect(num).to_not be(10)
        expect(num).to_not be(15)
      end
    end

    it "might cause a Generator Exhaustion if we filter too much" do
      never = PropCheck::Generators.integer().where { |val| val == nil }
      expect do
        PropCheck::forall(never) {}
      end.to raise_error do |error|
        expect(error).to be_a(PropCheck::Errors::GeneratorExhaustedError)
      end
    end

    it 'can be mapped over' do
      PG = PropCheck::Generators
      user_gen =
        PG.fixed_hash(name: PG.string, age: PG.integer)
          .map { |name:, age:| [name, age]}


    end
  end
end
