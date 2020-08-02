require 'doctest/rspec'


RSpec.describe PropCheck::Generator do
  Generator = PropCheck::Generator
  Generators = PropCheck::Generators
  doctest PropCheck::Generator

  # Used in a PropCheck::Generators doctest
  class User
    attr_accessor :name, :age
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

    # it 'filters properly' do
    #   class String
    #     BLANK_RE = /\A[[:space:]]*\z/

    #     # A string is blank if it's empty or contains whitespaces only:
    #     #
    #     #   ''.blank?       # => true
    #     #   '   '.blank?    # => true
    #     #   "\t\n\r".blank? # => true
    #     #   ' blah '.blank? # => false
    #     #
    #     # Unicode whitespace is supported:
    #     #
    #     #   "\u00a0".blank? # => true
    #     #
    #     def blank?
    #       # The regexp that matches blank strings is expensive. For the case of empty
    #       # strings we can speed up this method (~3.5x) with an empty? call. The
    #       # penalty for the rest of strings is marginal.
    #       empty? || BLANK_RE.match?(self)
    #     end
    #   end

    #   PG = PropCheck::Generators

    #   user_gen = PG.instance(User, name: PG.printable_ascii_string(empty: false).where { |str| !str.blank? }, age: PG.positive_integer)
    #   # res = PG.fixed_hash(x: PG.printable_string.where { |str| !str.blank? }).sample(10000)
    #   # res = user_gen.sample(10000)
    #   # expect(res.map(&:name)).to include(:"_PropCheck.filter_me")
    #   PropCheck.forall(user_gen) do |user|
    #     expect(user.name).to_not be(:"_PropCheck.filter_me")
    #   end
    # end

    describe "while shrinking" do
      it "will never allow filtered results" do
        PG = PropCheck::Generators
        # gen = PG.fixed_hash(x: PG.printable_string(empty: false).where { |str| !/\A[[:space:]]*\z/.match?(str) })
        gen = PG.integer.where { |val| val.odd? }
        expect(gen.generate.to_a).to_not include(:"_PropCheck.filter_me")
      end
    end
  end
end
