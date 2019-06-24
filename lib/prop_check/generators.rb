require 'prop_check/generator'
require 'prop_check/lazy_tree'
module PropCheck
  ##
  # Contains common generators.
  # Use this module by including it in the class (e.g. in your test suite)
  # where you want to use them.
  module Generators
    extend self
    ##
    # Always returns the same value, regardless of `size` or `rng` (random number generator state)
    #
    #   >> Generators.constant(10)
    def constant(val)
      Generator.wrap(val)
    end

    private def integer_shrink(val)
      # 0 cannot shrink further
      return [] if val.zero?

      # Numbers are shrunken by
      # subtracting themselves, their half, quarter, eight, ... (rounded towards zero!) from themselves, until the number itself is reached.
      # So: for 20 we have [0, 10, 15, 18, 19, 20]
      halvings =
        Helper.scanl(val) { |x| (x / 2.0).truncate }
          .take_while { |x| !x.zero? }
          .map { |x| val - x }
          .map { |x| LazyTree.new(x, integer_shrink(x)) }

      # For negative numbers, we also attempt if the positive number has the same result.
      if val.abs > val
        [LazyTree.new(val.abs, halvings)].lazy
      else
        halvings
      end
    end

    ##
    # Returns a random integer in the given range (if a range is given)
    # or between 0..num (if a single integer is given).
    #
    # Does not scale when `size` changes.
    # This means `choose` is useful for e.g. picking an element out of multiple possibilities,
    # but for other purposes you probably want to use `integer` et co.
    #
    #   >> r = Random.new(42); 10.times.map { Generators.choose(0..5).call(10, r) }
    #   => [3, 4, 2, 4, 4, 1, 2, 2, 2, 4]
    #   >> r = Random.new(42); 10.times.map { Generators.choose(0..5).call(20000, r) }
    #   => [3, 4, 2, 4, 4, 1, 2, 2, 2, 4]
    def choose(range)
      Generator.new do |_size, rng|
        val = rng.rand(range)
        LazyTree.new(val, integer_shrink(val))
      end
    end

    ##
    # A random integer which scales with `size`.
    # Integers start small (around 0)
    # and become more extreme (both higher and lower, negative) when `size` increases.
    #
    #   >> Generators.integer.call(2, Random.new(42))
    #   => 2
    #   >> Generators.integer.call(10000, Random.new(42))
    #   => 5795
    #   >> r = Random.new(42); 10.times.map { Generators.integer.call(20000, r) }
    #   => [-4205, -19140, 18158, -8716, -13735, -3150, 17194, 1962, -3977, -18315]
    def integer
      Generator.new do |size, rng|
        val = rng.rand(-size..size)
        LazyTree.new(val, integer_shrink(val))
      end
    end

    ##
    # Only returns integers that are zero or larger.
    # See `integer` for more information.
    def nonnegative_integer
      integer.map(&:abs)
    end

    ##
    # Only returns integers that are larger than zero.
    # See `integer` for more information.
    def positive_integer
      nonnegative_integer.map { |x| x + 1 }
    end

    ##
    # Only returns integers that are zero or smaller.
    # See `integer` for more information.
    def nonpositive_integer
      nonnegative_integer.map(&:-@)
    end

    ##
    # Only returns integers that are smaller than zero.
    # See `integer` for more information.
    def negative_integer
      positive_integer.map(&:-@)
    end

    private def fraction(a, b, c)
      a.to_f + b.to_f / (c.to_f.abs + 1.0)
    end

    ##
    # Generates floating point numbers
    # These start small (around 0)
    # and become more extreme (large positive and large negative numbers)
    # TODO testing for NaN, Infinity?
    def float
      # integer.bind do |a|
      #   integer.bind do |b|
      #     integer.bind do |c|
      #       Generator.wrap(fraction(a, b, c))
      #     end
      #   end
      # end
      tuple2(integer, integer, integer).map do |a, b, c|
        fraction(a, b, c)
      end
    end

    ##
    # Generates a single-character string
    # from the readable ASCII character set.
    #
    #   >> r = Random.new(42); 10.times.map{choose(32..128).map(&:chr).call(10, r) }
    #   => ["S", "|", ".", "g", "\\", "4", "r", "v", "j", "j"]
    def readable_ascii_char
      choose(32..128).map(&:chr)
    end

    ##
    # Picks one of the given `choices` at random uniformly every time.
    def one_of(*choices)
      choose(choices.length).bind do |index|
        choices[index]
      end
    end

    ##
    # Picks one of the choices given in `frequencies` at random every time.
    # `frequencies` expects keys to be numbers
    # (representing the relative frequency of this generator)
    # and values to be generators.
    #
    #   >> r = Random.new(42); 10.times.map { Generators.frequency(5 => Generators.integer, 1 => Generators.char).call(10, r) }
    #   => [4, -3, 10, 8, 0, -7, 10, 1, "E", 10]
    def frequency(frequencies)
      choices = frequencies.reduce([]) do |acc, elem|
        freq, val = elem
        acc + ([val] * freq)
      end
      one_of(*choices)
    end

    ##
    # Generates an array containing always exactly one value from each of the passed generators,
    # in the same order as specified:
    #
    #   >> Generators.tuple(Generators.integer, Generators.float).call(10, Random.new(42))
    #   => [-4, 3.1415]
    def tuple(*generators)
      generators.reduce(Generator.wrap([])) do |acc, generator|
        generator.bind do |val|
          acc.map { |x| x << val }
        end
      end
    end

    def tuple2(*generators)
      Generator.new do |size, rng|
        LazyTree.zip(generators.map do |generator|
          generator.generate(size, rng)
        end)
      end
    end

    ##
    # Given a `hash` where the values are generators,
    # creates a generator that returns hashes
    # with the same keys, and their corresponding values from their corresponding generators.
    #
    #    >> Generators.fixed_hash(a: Generators.integer(), b: Generators.float(), c: Generators.integer()).call(10, Random.new(42))
    #    => {:a=>-3, :b=>13.0, :c=>-4}
    def fixed_hash(hash)
      keypair_generators =
        hash.map do |key, generator|
          generator.map { |val| [key, val] }
        end

      tuple2(*keypair_generators)
        .map(&:to_h)
    end

    def array(element_generator)
      nonnegative_integer.bind do |generator|
        generators = (0...generator).map do
          element_generator.clone
        end

        tuple2(*generators)
      end
    end

    def hash(key_generator, value_generator)
      array(tuple2(key_generator, value_generator))
        .map(&:to_h)
    end

    def readable_ascii_string
      array(readable_ascii_char).map(&:join)
    end

    # TODO string
    # TODO unicode
    # TODO sets?
  end
end
