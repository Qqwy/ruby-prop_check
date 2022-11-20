# frozen_string_literal: true

require 'date'
require 'prop_check/generator'
require 'prop_check/lazy_tree'
module PropCheck
  ##
  # Contains common generators.
  # Use this module by including it in the class (e.g. in your test suite)
  # where you want to use them.
  module Generators
    module_function

    ##
    # Always returns the same value, regardless of `size` or `rng` (random number generator state)
    #
    # No shrinking (only considers the current single value `val`).
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
    # Shrinks to integers closer to zero.
    #
    #   >> r = Random.new(42); Generators.choose(0..5).sample(size: 10, rng: r)
    #   => [3, 4, 2, 4, 4, 1, 2, 2, 2, 4]
    #   >> r = Random.new(42); Generators.choose(0..5).sample(size: 20000, rng: r)
    #   => [3, 4, 2, 4, 4, 1, 2, 2, 2, 4]
    def choose(range)
      Generator.new do |rng:, **|
        val = rng.rand(range)
        LazyTree.new(val, integer_shrink(val))
      end
    end

    ##
    # A random integer which scales with `size`.
    # Integers start small (around 0)
    # and become more extreme (both higher and lower, negative) when `size` increases.
    #
    #
    # Shrinks to integers closer to zero.
    #
    #   >> Generators.integer.call(size: 2, rng: Random.new(42))
    #   => 1
    #   >> Generators.integer.call(size: 10000, rng: Random.new(42))
    #   => 5795
    #   >> r = Random.new(42); Generators.integer.sample(size: 20000, rng: r)
    #   => [-4205, -19140, 18158, -8716, -13735, -3150, 17194, 1962, -3977, -18315]
    def integer
      Generator.new do |size:, rng:, **|
        ensure_proper_size!(size)

        val = rng.rand(-size..size)
        LazyTree.new(val, integer_shrink(val))
      end
    end

    private def ensure_proper_size!(size)
      return if size.is_a?(Integer) && size >= 0

      raise ArgumentError, "`size:` should be a nonnegative integer but got `#{size.inspect}`"
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
    # Generates floating-point numbers
    # These start small (around 0)
    # and become more extreme (large positive and large negative numbers)
    #
    # Will only generate 'reals',
    # that is: no infinity, no NaN,
    # no numbers testing the limits of floating-point arithmetic.
    #
    # Shrinks towards zero.
    # The shrinking strategy also moves towards 'simpler' floats (like `1.0`) from 'complicated' floats (like `3.76543`).
    #
    #    >> Generators.real_float().sample(10, size: 10, rng: Random.new(42))
    #    => [-2.2, -0.2727272727272727, 4.0, 1.25, -3.7272727272727275, -8.833333333333334, -8.090909090909092, 1.1428571428571428, 0.0, 8.0]
    def real_float
      tuple(integer, integer, integer).map do |a, b, c|
        fraction(a, b, c)
      end
    end

    ##
    # Generates any real floating-point numbers,
    # but will never generate zero.
    # c.f. #real_float
    #
    #    >> Generators.real_nonzero_float().sample(10, size: 10, rng: Random.new(43))
    #    => [-7.25, 7.125, -7.636363636363637, -3.0, -8.444444444444445, -6.857142857142857, 2.4545454545454546, 3.0, -7.454545454545455, -6.25]
    def real_nonzero_float
      real_float.where { |val| val != 0.0 }
    end

    ##
    # Generates real floating-point numbers which are never negative.
    # Shrinks towards 0
    # c.f. #real_float
    #
    #    >> Generators.real_nonnegative_float().sample(10, size: 10, rng: Random.new(43))
    #    => [7.25, 7.125, 7.636363636363637, 3.0, 8.444444444444445, 0.0, 6.857142857142857, 2.4545454545454546, 3.0, 7.454545454545455]
    def real_nonnegative_float
      real_float.map(&:abs)
    end

    ##
    # Generates real floating-point numbers which are never positive.
    # Shrinks towards 0
    # c.f. #real_float
    #
    #    >> Generators.real_nonpositive_float().sample(10, size: 10, rng: Random.new(44))
    #    => [-9.125, -2.3636363636363638, -8.833333333333334, -1.75, -8.4, -2.4, -3.5714285714285716, -1.0, -6.111111111111111, -4.0]
    def real_nonpositive_float
      real_nonnegative_float.map(&:-@)
    end

    ##
    # Generates real floating-point numbers which are always positive
    # Shrinks towards Float::MIN
    #
    # Does not consider denormals.
    # c.f. #real_float
    #
    #    >> Generators.real_positive_float().sample(10, size: 10, rng: Random.new(42))
    #    => [2.2, 0.2727272727272727, 4.0, 1.25, 3.7272727272727275, 8.833333333333334, 8.090909090909092, 1.1428571428571428, 2.2250738585072014e-308, 8.0]
    def real_positive_float
      real_nonnegative_float.map { |val| val + Float::MIN }
    end

    ##
    # Generates real floating-point numbers which are always negative
    # Shrinks towards -Float::MIN
    #
    # Does not consider denormals.
    # c.f. #real_float
    #
    #    >> Generators.real_negative_float().sample(10, size: 10, rng: Random.new(42))
    #    => [-2.2, -0.2727272727272727, -4.0, -1.25, -3.7272727272727275, -8.833333333333334, -8.090909090909092, -1.1428571428571428, -2.2250738585072014e-308, -8.0]
    def real_negative_float
      real_positive_float.map(&:-@)
    end

    @@special_floats = [Float::NAN,
                        Float::INFINITY,
                        -Float::INFINITY,
                        Float::MAX,
                        -Float::MAX,
                        Float::MIN,
                        -Float::MIN,
                        Float::EPSILON,
                        -Float::EPSILON,
                        0.0.next_float,
                        0.0.prev_float]
    ##
    # Generates floating-point numbers
    # Will generate NaN, Infinity, -Infinity,
    # as well as Float::EPSILON, Float::MAX, Float::MIN,
    # 0.0.next_float, 0.0.prev_float,
    # to test the handling of floating-point edge cases.
    # Approx. 1/50 generated numbers is a special one.
    #
    # Shrinks to smaller, real floats.
    #    >> Generators.float().sample(10, size: 10, rng: Random.new(42))
    #    >>  Generators.float().sample(10, size: 10, rng: Random.new(4))
    #    => [-8.0, 2.0, 2.7142857142857144, -4.0, -10.2, -6.666666666666667, -Float::INFINITY, -10.2, 2.1818181818181817, -6.2]
    def float
      frequency(49 => real_float, 1 => one_of(*@@special_floats.map(&method(:constant))))
    end

    ##
    # Generates any nonzerno floating-point number.
    # Will generate special floats (except NaN) from time to time.
    # c.f. #float
    def nonzero_float
      float.where { |val| val != 0.0 && val }
    end

    ##
    # Generates nonnegative floating point numbers
    # Will generate special floats (except NaN) from time to time.
    # c.f. #float
    def nonnegative_float
      float.map(&:abs).where { |val| val != Float::NAN }
    end

    ##
    # Generates nonpositive floating point numbers
    # Will generate special floats (except NaN) from time to time.
    # c.f. #float
    def nonpositive_float
      nonnegative_float.map(&:-@)
    end

    ##
    # Generates positive floating point numbers
    # Will generate special floats (except NaN) from time to time.
    # c.f. #float
    def positive_float
      nonnegative_float.where { |val| val != 0.0 && val }
    end

    ##
    # Generates positive floating point numbers
    # Will generate special floats (except NaN) from time to time.
    # c.f. #float
    def negative_float
      positive_float.map(&:-@).where { |val| val != 0.0 }
    end

    ##
    # Picks one of the given generators in `choices` at random uniformly every time.
    #
    # Shrinks to values earlier in the list of `choices`.
    #
    #    >> Generators.one_of(Generators.constant(true), Generators.constant(false)).sample(5, size: 10, rng: Random.new(42))
    #    => [true, false, true, true, true]
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
    # Side note: If you want to use the same frequency number for multiple generators,
    # Ruby syntax requires you to send an array of two-element arrays instead of a hash.
    #
    # Shrinks to arbitrary elements (since hashes are not ordered).
    #
    #   >> Generators.frequency(5 => Generators.integer, 1 => Generators.printable_ascii_char).sample(size: 10, rng: Random.new(42))
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
    # Shrinks element generators, one at a time (trying last one first).
    #
    #   >> Generators.tuple(Generators.integer, Generators.real_float).call(size: 10, rng: Random.new(42))
    #   => [-4, 13.0]
    def tuple(*generators)
      Generator.new do |**kwargs|
        LazyTree.zip(generators.map do |generator|
          generator.generate(**kwargs)
        end)
      end
    end

    ##
    # Given a `hash` where the values are generators,
    # creates a generator that returns hashes
    # with the same keys, and their corresponding values from their corresponding generators.
    #
    # Shrinks element generators.
    #
    #    >> Generators.fixed_hash(a: Generators.integer(), b: Generators.real_float(), c: Generators.integer()).call(size: 10, rng: Random.new(42))
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
    # Accepted keyword arguments:
    #
    # `empty:` When false, behaves the same as `min: 1`
    # `min:` Ensures at least this many elements are generated. (default: 0)
    # `max:` Ensures at most this many elements are generated. When nil, an arbitrary count is used instead. (default: nil)
    # `uniq:` When `true`, ensures that all elements in the array are unique.
    #         When given a proc, uses the result of this proc to check for uniqueness.
    #         (matching the behaviour of `Array#uniq`)
    #         If it is not possible to generate another unique value after the configured `max_consecutive_attempts`
    #         an `PropCheck::Errors::GeneratorExhaustedError` will be raised.
    #         (default: `false`)
    #
    #
    #    >> Generators.array(Generators.positive_integer).sample(5, size: 1, rng: Random.new(42))
    #    =>  [[2], [2], [2], [1], [2]]
    #    >> Generators.array(Generators.positive_integer).sample(5, size: 10, rng: Random.new(42))
    #    => [[10, 5, 1, 4], [5, 9, 1, 1, 11, 8, 4, 9, 11, 10], [6], [11, 11, 2, 2, 7, 2, 6, 5, 5], [2, 10, 9, 7, 9, 5, 11, 3]]
    #
    #    >> Generators.array(Generators.positive_integer, empty: true).sample(5, size: 1, rng: Random.new(1))
    #    =>  [[], [2], [], [], [2]]
    #    >> Generators.array(Generators.positive_integer, empty: false).sample(5, size: 1, rng: Random.new(1))
    #    =>  [[2], [1], [2], [1], [1]]
    #
    #    >> Generators.array(Generators.boolean, uniq: true).sample(5, rng: Random.new(1))
    #    => [[true, false], [false, true], [true, false], [false, true], [false, true]]

    def array(element_generator, min: 0, max: nil, empty: true, uniq: false)
      min = 1 if min.zero? && !empty
      uniq = proc { |x| x } if uniq == true

      if max.nil?
        nonnegative_integer.bind { |count| make_array(element_generator, min, count, uniq) }
      else
        make_array(element_generator, min, max, uniq)
      end
    end

    private def make_array(element_generator, min, count, uniq)
      amount = min if count < min
      amount = min if count == min && min != 0
      amount ||= (count - min)

      # Simple, optimized implementation:
      return make_array_simple(element_generator, amount) unless uniq

      # More complex implementation that filters duplicates
      make_array_uniq(element_generator, min, amount, uniq)
    end

    private def make_array_simple(element_generator, amount)
      generators = amount.times.map do
        element_generator.clone
      end

      tuple(*generators)
    end

    private def make_array_uniq(element_generator, min, amount, uniq_fun)
      Generator.new do |**kwargs|
        arr = []
        uniques = Set.new
        count = 0
        0.step.lazy.map do
          elem = element_generator.clone.generate(**kwargs)
          if uniques.add?(uniq_fun.call(elem.root))
            arr.push(elem)
            count = 0
          else
            count += 1
          end

          if count > kwargs[:max_consecutive_attempts]
            if arr.size >= min
              # Give up and return shorter array in this case
              amount = min
            else
              raise Errors::GeneratorExhaustedError, "Too many consecutive elements filtered by 'uniq:'."
            end
          end
        end
         .take_while { arr.size < amount }
         .force

        LazyTree.zip(arr).map { |array| array.uniq(&uniq_fun) }
      end
    end

    ##
    # Generates a set of elements, where each of the elements
    # is generated by `element_generator`.
    #
    # Shrinks to smaller sets (with shrunken elements).
    # Accepted keyword arguments:
    #
    # `empty:` When false, behaves the same as `min: 1`
    # `min:` Ensures at least this many elements are generated. (default: 0)
    # `max:` Ensures at most this many elements are generated. When nil, an arbitrary count is used instead. (default: nil)
    #
    # In the set, elements are always unique.
    # If it is not possible to generate another unique value after the configured `max_consecutive_attempts`
    # a `PropCheck::Errors::GeneratorExhaustedError` will be raised.
    def set(element_generator, min: 0, max: nil, empty: true)
      array(element_generator, min: min, max: max, empty: empty, uniq: true).map(&:to_set)
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
    def hash(*args, **kwargs)
      if args.length == 2
        hash_of(*args, **kwargs)
      else
        super
      end
    end

    ##
    #
    # Alias for `#hash` that does not conflict with a possibly overriden `Object#hash`.
    #
    def hash_of(key_generator, value_generator, **kwargs)
      array(tuple(key_generator, value_generator), **kwargs)
        .map(&:to_h)
    end

    @@alphanumeric_chars = [('a'..'z'), ('A'..'Z'), ('0'..'9')].flat_map(&:to_a).freeze
    ##
    # Generates a single-character string
    # containing one of a..z, A..Z, 0..9
    #
    # Shrinks towards lowercase 'a'.
    #
    #    >> Generators.alphanumeric_char.sample(5, size: 10, rng: Random.new(42))
    #    => ["M", "Z", "C", "o", "Q"]
    def alphanumeric_char
      one_of(*@@alphanumeric_chars.map(&method(:constant)))
    end

    ##
    # Generates a string
    # containing only the characters a..z, A..Z, 0..9
    #
    # Shrinks towards fewer characters, and towards lowercase 'a'.
    #
    #    >> Generators.alphanumeric_string.sample(5, size: 10, rng: Random.new(42))
    #    => ["ZCoQ", "8uM", "wkkx0JNx", "v0bxRDLb", "Gl5v8RyWA6"]
    #
    # Accepts the same options as `array`
    def alphanumeric_string(**kwargs)
      array(alphanumeric_char, **kwargs).map(&:join)
    end

    @@printable_ascii_chars = (' '..'~').to_a.freeze

    ##
    # Generates a single-character string
    # from the printable ASCII character set.
    #
    # Shrinks towards ' '.
    #
    #   >> Generators.printable_ascii_char.sample(size: 10, rng: Random.new(42))
    #   => ["S", "|", ".", "g", "\\", "4", "r", "v", "j", "j"]
    def printable_ascii_char
      one_of(*@@printable_ascii_chars.map(&method(:constant)))
    end

    ##
    # Generates strings
    # from the printable ASCII character set.
    #
    # Shrinks towards fewer characters, and towards ' '.
    #
    #    >> Generators.printable_ascii_string.sample(5, size: 10, rng: Random.new(42))
    #    => ["S|.g", "rvjjw7\"5T!", "=", "!_[4@", "Y"]
    #
    # Accepts the same options as `array`
    def printable_ascii_string(**kwargs)
      array(printable_ascii_char, **kwargs).map(&:join)
    end

    @@ascii_chars = [
      @@printable_ascii_chars,
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

    ##
    # Generates a single-character string
    # from the printable ASCII character set.
    #
    # Shrinks towards '\n'.
    #
    #    >> Generators.ascii_char.sample(size: 10, rng: Random.new(42))
    #    => ["d", "S", "|", ".", "g", "\\", "4", "d", "r", "v"]
    def ascii_char
      one_of(*@@ascii_chars.map(&method(:constant)))
    end

    ##
    # Generates strings
    # from the printable ASCII character set.
    #
    # Shrinks towards fewer characters, and towards '\n'.
    #
    #    >> Generators.ascii_string.sample(5, size: 10, rng: Random.new(42))
    #    => ["S|.g", "drvjjw\b\a7\"", "!w=E!_[4@k", "x", "zZI{[o"]
    #
    # Accepts the same options as `array`
    def ascii_string(**kwargs)
      array(ascii_char, **kwargs).map(&:join)
    end

    @@printable_chars = [
      @@ascii_chars,
      "\u{A0}".."\u{D7FF}",
      "\u{E000}".."\u{FFFD}",
      "\u{10000}".."\u{10FFFF}"
    ].flat_map(&:to_a).freeze

    ##
    # Generates a single-character printable string
    # both ASCII characters and Unicode.
    #
    # Shrinks towards characters with lower codepoints, e.g. ASCII
    #
    #    >> Generators.printable_char.sample(size: 10, rng: Random.new(42))
    #    => ["吏", "", "", "", "", "", "", "", "", "Ȍ"]
    def printable_char
      one_of(*@@printable_chars.map(&method(:constant)))
    end

    ##
    # Generates a printable string
    # both ASCII characters and Unicode.
    #
    # Shrinks towards shorter strings, and towards characters with lower codepoints, e.g. ASCII
    #
    #    >> Generators.printable_string.sample(5, size: 10, rng: Random.new(42))
    #    => ["", "Ȍ", "𐁂", "Ȕ", ""]
    #
    # Accepts the same options as `array`
    def printable_string(**kwargs)
      array(printable_char, **kwargs).map(&:join)
    end

    ##
    # Generates a single unicode character
    # (both printable and non-printable).
    #
    # Shrinks towards characters with lower codepoints, e.g. ASCII
    #
    #    >> Generators.printable_char.sample(size: 10, rng: Random.new(42))
    #    => ["吏", "", "", "", "", "", "", "", "", "Ȍ"]
    def char
      choose(0..0x10FFFF).map do |num|
        [num].pack('U')
      end
    end

    ##
    # Generates a string of unicode characters
    # (which might contain both printable and non-printable characters).
    #
    # Shrinks towards characters with lower codepoints, e.g. ASCII
    #
    #    >> Generators.string.sample(5, size: 10, rng: Random.new(42))
    #    => ["\u{A3DB3}𠍜\u{3F46A}\u{1AEBC}", "􍙦𡡹󴇒\u{DED74}𪱣\u{43E97}ꂂ\u{50695}􏴴\u{C0301}", "\u{4FD9D}", "\u{C14BF}\u{193BB}𭇋󱣼\u{76B58}", "𦐺\u{9FDDB}\u{80ABB}\u{9E3CF}𐂽\u{14AAE}"]
    #
    # Accepts the same options as `array`
    def string(**kwargs)
      array(char, **kwargs).map(&:join)
    end

    ##
    # Generates either `true` or `false`
    #
    # Shrinks towards `false`
    #
    #    >> Generators.boolean.sample(5, size: 10, rng: Random.new(42))
    #    => [false, true, false, false, false]
    def boolean
      one_of(constant(false), constant(true))
    end

    ##
    # Generates always `nil`.
    #
    # Does not shrink.
    #
    #    >> Generators.nil.sample(5, size: 10, rng: Random.new(42))
    #    => [nil, nil, nil, nil, nil]
    def nil
      constant(nil)
    end

    ##
    # Generates `nil` or `false`.
    #
    # Shrinks towards `nil`.
    #
    #    >> Generators.falsey.sample(5, size: 10, rng: Random.new(42))
    #    => [nil, false, nil, nil, nil]
    def falsey
      one_of(constant(nil), constant(false))
    end

    ##
    # Generates symbols consisting of lowercase letters and potentially underscores.
    #
    # Shrinks towards shorter symbols and the letter 'a'.
    #
    #    >> Generators.simple_symbol.sample(5, size: 10, rng: Random.new(42))
    #    => [:tokh, :gzswkkxudh, :vubxlfbu, :lzvlyq__jp, :oslw]
    def simple_symbol
      alphabet = ('a'..'z').to_a
      alphabet << '_'
      array(one_of(*alphabet.map(&method(:constant))))
        .map(&:join)
        .map(&:to_sym)
    end

    ##
    # Generates common terms that are not `nil` or `false`.
    #
    # Shrinks towards simpler terms, like `true`, an empty array, a single character or an integer.
    #
    #    >> Generators.truthy.sample(5, size: 2, rng: Random.new(42))
    #    => [[2], {:gz=>0, :""=>0}, [1.0, 0.5], 0.6666666666666667, {"𦐺\u{9FDDB}"=>1, ""=>1}]
    def truthy
      one_of(constant(true),
             constant([]),
             char,
             integer,
             float,
             string,
             array(integer),
             array(float),
             array(char),
             array(string),
             hash(simple_symbol, integer),
             hash(string, integer),
             hash(string, string))
    end

    ##
    # Generates whatever `other_generator` generates
    # but sometimes instead `nil`.`
    #
    #    >> Generators.nillable(Generators.integer).sample(20, size: 10, rng: Random.new(42))
    #    => [9, 10, 8, 0, 10, -3, -8, 10, 1, -9, -10, nil, 1, 6, nil, 1, 9, -8, 8, 10]
    def nillable(other_generator)
      frequency(9 => other_generator, 1 => constant(nil))
    end

    ##
    # Generates `Date` objects.
    # DateTimes start around the given `epoch:`  and deviate more when `size` increases.
    # when no epoch is set, `PropCheck::Property::Configuration.default_epoch` is used, which defaults to `DateTime.now.to_date`.
    #
    #   >> Generators.date(epoch: Date.new(2022, 01, 01)).sample(2, rng: Random.new(42))
    #   => [Date.new(2021, 12, 28), Date.new(2022, 01, 10)]
    def date(epoch: nil)
      date_from_offset(integer, epoch: epoch)
    end

    ##
    # variant of #date that only generates dates in the future (relative to `:epoch`).
    #
    #   >> Generators.future_date(epoch: Date.new(2022, 01, 01)).sample(2, rng: Random.new(42))
    #   => [Date.new(2022, 01, 06), Date.new(2022, 01, 11)]
    def future_date(epoch: Date.today)
      date_from_offset(positive_integer, epoch: epoch)
    end

    ##
    # variant of #date that only generates dates in the past (relative to `:epoch`).
    #
    #   >> Generators.past_date(epoch: Date.new(2022, 01, 01)).sample(2, rng: Random.new(42))
    #   => [Date.new(2021, 12, 27), Date.new(2021, 12, 22)]
    def past_date(epoch: Date.today)
      date_from_offset(negative_integer, epoch: epoch)
    end

    private def date_from_offset(offset_gen, epoch:)
      if epoch
        offset_gen.map { |offset| Date.jd(epoch.jd + offset) }
      else
        offset_gen.with_config.map do |offset, config|
          puts config.inspect
          epoch = config.default_epoch.to_date
          Date.jd(epoch.jd + offset)
        end
      end
    end

    ##
    # Generates `DateTime` objects.
    # DateTimes start around the given `epoch:`  and deviate more when `size` increases.
    # when no epoch is set, `PropCheck::Property::Configuration.default_epoch` is used, which defaults to `DateTime.now`.
    #
    #   >> PropCheck::Generators.datetime.sample(2, rng: Random.new(42), config: PropCheck::Property::Configuration.new)
    #   => [DateTime.parse("2022-11-17 07:11:59.999983907 +0000"), DateTime.parse("2022-11-19 05:27:16.363618076 +0000")]
    def datetime(epoch: nil)
      datetime_from_offset(real_float, epoch: epoch)
    end

    ##
    # alias for `#datetime`, for backwards compatibility.
    # Prefer using `datetime`!
    def date_time(epoch: nil)
      datetime(epoch: epoch)
    end

    ##
    # Variant of `#datetime` that only generates datetimes in the future (relative to `:epoch`).
    #
    #   >> PropCheck::Generators.future_datetime.sample(2, rng: Random.new(42), config: PropCheck::Property::Configuration.new).map(&:inspect)
    #   => ["#<DateTime: 2022-11-21T16:48:00+00:00 ((2459905j,60480s,16093n),+0s,2299161j)>", "#<DateTime: 2022-11-19T18:32:43+00:00 ((2459903j,66763s,636381924n),+0s,2299161j)>"]
    def future_datetime(epoch: nil)
      datetime_from_offset(real_positive_float, epoch: epoch)
    end

    ##
    # Variant of `#datetime` that only generates datetimes in the past (relative to `:epoch`).
    #
    #   >> PropCheck::Generators.past_datetime.sample(2, rng: Random.new(42), config: PropCheck::Property::Configuration.new)
    #   => [DateTime.parse("2022-11-17 07:11:59.999983907 +0000"), DateTime.parse("2022-11-19 05:27:16.363618076 +0000")]
    def past_datetime(epoch: nil)
      datetime_from_offset(real_negative_float, epoch: epoch)
    end

    ##
    # Generates `Time` objects.
    # Times start around the given `epoch:`  and deviate more when `size` increases.
    # when no epoch is set, `PropCheck::Property::Configuration.default_epoch` is used, which defaults to `DateTime.now`.
    #
    #   >> PropCheck::Generators.time.sample(2, rng: Random.new(42), config: PropCheck::Property::Configuration.new)
    #   => [DateTime.parse("2022-11-17 07:11:59.999983907 +0000").to_time, DateTime.parse("2022-11-19 05:27:16.363618076 +0000").to_time]
    def time(epoch: nil)
      datetime(epoch: epoch).map(&:to_time)
    end

    ##
    # Variant of `#time` that only generates datetimes in the future (relative to `:epoch`).
    def future_time(epoch: nil)
      future_datetime(epoch: epoch).map(&:to_time)
    end

    ##
    # Variant of `#time` that only generates datetimes in the past (relative to `:epoch`).
    def past_time(epoch: nil)
      past_datetime(epoch: epoch).map(&:to_time)
    end

    private def datetime_from_offset(offset_gen, epoch:)
      if epoch
        offset_gen.map { |offset| DateTime.jd(epoch.ajd + offset) }
      else
        offset_gen.with_config.map do |offset, config|
          epoch = config.default_epoch.to_date
          DateTime.jd(epoch.ajd + offset)
        end
      end
    end

    ##
    # Generates an instance of `klass`
    # using `args` and/or `kwargs`
    # as generators for the arguments that are passed to `klass.new`
    #
    # ## Example:
    #
    # Given a class like this:
    #
    #
    #    class User
    #      attr_accessor :name, :age
    #      def initialize(name: , age: )
    #        @name = name
    #        @age = age
    #      end
    #
    #      def inspect
    #        "<User name: #{@name.inspect}, age: #{@age.inspect}>"
    #      end
    #    end
    #
    #   >> user_gen = Generators.instance(User, name: Generators.printable_ascii_string, age: Generators.nonnegative_integer)
    #   >> user_gen.sample(3, rng: Random.new(42)).inspect
    #   => "[<User name: \"S|.g\", age: 10>, <User name: \"rvjj\", age: 10>, <User name: \"7\\\"5T!w=\", age: 5>]"
    def instance(klass, *args, **kwargs)
      tuple(*args).bind do |vals|
        fixed_hash(**kwargs).map do |kwvals|
          if kwvals == {}
            klass.new(*vals)
          elsif vals == []
            klass.new(**kwvals)
          else
            klass.new(*vals, **kwvals)
          end
        end
      end
    end
  end
end
