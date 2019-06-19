module Helper
  def self.scanl(elem, &op)
    Enumerator.new do |yielder|
      acc = elem
      loop do
        yielder << acc
        acc = op.call(acc)
      end
    end.lazy
  end
end

class Generator
  attr_accessor :generate_proc, :shrink_proc

  def initialize(generate: , shrink: proc { |_, _, _| [] })
    self.generate_proc = generate
    self.shrink_proc = shrink
  end

  def call(size, rng)
    generate_proc.call(size, rng)
  end

  def shrink(generated_val, size, rng)
    shrink_proc.call(generated_val, size, rng)
  end

  def map(&change)
    Generator.new(
      generate: proc { |size, rng| change.call(generate_proc.call(size, rng)) },
      shrink: proc { |val, size, rng| change.call(shrink_proc.call(val, size, rng)) }
    )
  end

  # Monadic 'return'/'pure'
  def self.wrap(val)
    Generator.new(generate: proc { | _size, _rng| val}, shrink: proc { |val, _size, _rng| p val; [] })
  end

  # Monadic 'bind', allowing you to create a generator that depends on another generator for input.
  def bind(&generator_proc)
    gen_val = proc do |size, rng|
      generated_input = self.call(size, rng)
      initialized_generator = generator_proc.call(generated_input)
      initialized_generator.call(size, rng)

    end

    Generator.new(
      generate: gen_val,
      # First shrink inner generator
      # and afterwards, shrink outer (and shrink inner again for each of the outer calls).
      shrink: proc do |_val, size, rng|

        rng2 = rng.dup
        generated_input = self.call(size, rng.dup)
        # initialized_generator = generator_proc.call(generated_input)
        # previous_val = initialized_generator.call(size, rng2)

        # rng2 = rng.dup
        # simple_shrink_candidates = initialized_generator.shrink(previous_val, size, rng2)

        rng2 = rng.dup
        [[generated_input], self.shrink(generated_input, size, rng.dup)].lazy.flat_map(&:lazy)
          .map do |val|
          p val

          initialized_generator = generator_proc.call(val)
          previous_val = initialized_generator.call(size, rng2.dup)
          p previous_val
          [[previous_val], initialized_generator.shrink(previous_val, size, rng2.dup)].lazy.flat_map(&:lazy)
        end.lazy.flat_map(&:lazy)
        # complex_shrink_candidates = self.shrink(generated_input, size, rng2).flat_map do |val|
        #   initialized_generator = generator_proc.call(val)
        #   ival = initialized_generator.call(size, rng2.dup)

        #   p [val, ival]
        #   [[ival], initialized_generator.shrink(ival, size, rng2.dup)].lazy.flat_map(&:lazy)
        # end

        # simple_shrink_candidates
        # [simple_shrink_candidates, complex_shrink_candidates].lazy.flat_map(&:lazy)
      end
    )
  end
end

module Generators
  def constant(val)
    Generator.wrap(a)
  end

  private def integer_shrink(val)
    return [] if val.zero?

    res = []
    res << -val if val.abs > val

    halvings = Helper.scanl(val) { |x| (x / 2.0).truncate }
                 .take_while { |x| !x.zero? }
                 .map { |x| val - x }

    [res, halvings].lazy.flat_map(&:lazy)
  end

  def choose(range)
    Generator.new(
      generate: proc { |_size, rng| rng.rand(range) },
      shrink: proc { |val, size, rng| integer_shrink(val)}
    )
  end

  def integer
    Generator.new(
      generate: proc { |size, rng| rng.rand(-size..size) },
      shrink: proc { |val, size, rng| integer_shrink(val)}
    )
  end

  private def fraction(a, b, c)
    a.to_f + b.to_f / ((c.to_f.abs) + 1.0)
  end

  def float
    integer.bind do |a|
      integer.bind do |b|
        integer.bind do |c|
          Generator.wrap(fraction(a, b, c))
        end
      end
    end
  end
end

include Generators

# halvings = scanl(n) { |x| x / 2 }.take_while { |x| !x.zero? }
