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
    #   >> Generators.constant("pie").sample(5, size: 10, rng: Random.new(42))
    #   => ["pie", "pie", "pie", "pie", "pie"]
    def constant(val)
      Generator.wrap(val)
    end

    private def integer_shrink(val)
      # 0 cannot shrink further; base case
      return [] if val.zero?

      # Numbers are shrunken by
      # subtracting themselves, their half, quarter, eight, ... (rounded towards zero!)
      # from themselves, until the number itself is reached.
      # So: for 20 we have [0, 10, 15, 18, 19, 20]
      halvings =
        Helper
        .scanl(val) { |x| (x / 2.0).truncate }
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
    #   >> r = Random.new(42); Generators.choose(0..5).sample(size: 10, rng: r)
    #   => [3, 4, 2, 4, 4, 1, 2, 2, 2, 4]
    #   >> r = Random.new(42); Generators.choose(0..5).sample(size: 20000, rng: r)
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
    #   => 1
    #   >> Generators.integer.call(10000, Random.new(42))
    #   => 5795
    #   >> r = Random.new(42); Generators.integer.sample(size: 20000, rng: r)
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

    private def fraction(num_a, num_b, num_c)
      num_a.to_f + num_b.to_f / (num_c.to_f.abs + 1.0)
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
      tuple(integer, integer, integer).map do |a, b, c|
        fraction(a, b, c)
      end
    end

    ##
    # Picks one of the given `choices` at random uniformly every time.
    def one_of(*choices)
      choose(choices.length).bind do |index|
        constant(choices[index])
      end
    end

    ##
    # Picks one of the choices given in `frequencies` at random every time.
    # `frequencies` expects keys to be numbers
    # (representing the relative frequency of this generator)
    # and values to be generators.
    #
    #   >> Generators.frequency(5 => Generators.integer, 1 => Generators.printable_ascii_char).sample(size: 10, rng: Random.new(42))
    #   => [4, -3, 10, 8, 0, -7, 10, 1, "E", 10]
    def frequency(frequencies)
      choices = frequencies.reduce([]) do |acc, elem|
        freq, val = elem
        acc + ([val] * freq)
      end
      one_of(*choices).bind do |chosen_generator|
        chosen_generator
      end
    end

    ##
    # Generates an array containing always exactly one value from each of the passed generators,
    # in the same order as specified:
    #
    #   >> Generators.tuple(Generators.integer, Generators.float).call(10, Random.new(42))
    #   => [-4, 13.0]
    def tuple(*generators)
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
    #    => {:a=>-4, :b=>13.0, :c=>-3}
    def fixed_hash(hash)
      keypair_generators =
        hash.map do |key, generator|
          generator.map { |val| [key, val] }
        end

      tuple(*keypair_generators)
        .map(&:to_h)
    end

    ##
    # Generates an array of elements, where each of the elements
    # is generated by `element_generator`.
    #
    # Shrinks to shorter arrays (with shrunken elements).
    #
    #    >> Generators.array(Generators.positive_integer).sample(5, size: 10, rng: Random.new(42))
    #    => [[10, 5, 1, 4], [5, 9, 1, 1, 11, 8, 4, 9, 11, 10], [6], [11, 11, 2, 2, 7, 2, 6, 5, 5], [2, 10, 9, 7, 9, 5, 11, 3]]
    def array(element_generator)
      nonnegative_integer.bind do |generator|
        generators = (0...generator).map do
          element_generator.clone
        end

        tuple(*generators)
      end
    end

    ##
    # Generates a hash of key->values,
    # where each of the keys is made using the `key_generator`
    # and each of the values using the `value_generator`.
    #
    # Shrinks to hashes with less key/value pairs.
    #
    #    >> Generators.hash(Generators.printable_ascii_string, Generators.positive_integer).sample(5, size: 3, rng: Random.new(42))
    #    => [{""=>2, "g\\4"=>4, "rv"=>2}, {"7"=>2}, {"!"=>1, "E!"=>1}, {"kY5"=>2}, {}]
    def hash(key_generator, value_generator)
      array(tuple(key_generator, value_generator))
        .map(&:to_h)
    end


    @alphanumeric_chars = [('a'..'z'), ('A'..'Z'), ('0'..'9')].flat_map(&:to_a).freeze
    ##
    # Generates a single-character string
    # containing one of a..z, A..Z, 0..9
    def alphanumeric_char
      one_of(*@alphanumeric_chars)
    end

    ##
    # Generates a string
    # containing only the characters a..z, A..Z, 0..9
    def alphanumeric_string
      array(alphanumeric_char).map(&:join)
    end


    ##
    # Generates a single-character string
    # from the printable ASCII character set.
    #
    #   >> Generators.printable_ascii_char.sample(size: 10, rng: Random.new(42))
    #   => ["S", "|", ".", "g", "\\", "4", "r", "v", "j", "j"]
    @printable_ascii_chars = (' '..'~').to_a.freeze
    def printable_ascii_char
      one_of(*@printable_ascii_chars)
    end

    def printable_ascii_string
      array(printable_ascii_char).map(&:join)
    end

    @ascii_chars = [
      @printable_ascii_chars,
      [
        "\n",
        "\r",
        "\t",
        "\v",
        "\b",
        "\f",
        "\e",
        "\d",
        "\a"
      ]
    ].flat_map(&:to_a).freeze
    def ascii_char
      one_of(*@ascii_chars)
    end

    def ascii_string
      array(ascii_char).map(&:join)
    end

    @printable_chars = [
      @ascii_chars,
      "\u{A0}".."\u{D7FF}",
      "\u{E000}".."\u{FFFD}",
      "\u{10000}".."\u{10FFFF}"
    ].flat_map(&:to_a).freeze

    ##
    # Generates a single-character printable string
    # both ASCII characters and Unicode.
    def printable_char
      one_of(*@printable_chars)
    end

    ##
    # Generates a printable string
    # both ASCII characters and Unicode.
    def printable_string
      array(printable_char).map(&:join)
    end

    ##
    # Generates a single unicode character
    # (both printable and non-printable).
    def char
      choose(0..0x10FFFF).map do |num|
        [num].pack('U')
      end
    end

    ##
    # Generates a string of unicode characters
    # (which might contain both printable and non-printable characters).
    def string
      array(char).map(&:join)
    end
  end
end
