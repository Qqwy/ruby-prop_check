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

  def initialize(generate: , shrink: proc { [] })
    self.generate_proc = generate
    self.shrink_proc = shrink
  end

  def call(size, rng)
    generate_proc.call(size, rng)
  end

  def shrink(generated_val)
    shrink_proc.call(generated_val)
  end

  def map(&change)
    Generator.new(
      generate: proc { |size, rng| change.call(generate_proc.call(size, rng)) },
      shrink: proc { |val| change.call(shrink_proc.call(val)) }
    )
  end

  # Monadic 'return'/'pure'
  def self.wrap(val)
    Generator.new(generate: proc { | _size, _rng| val}, shrink: proc { |val| [] })
  end

  # Monadic 'bind', allowing you to create a generator that depends on another generator for input.
  def bind(&generator_proc)
    Generator.new(
      generate: proc do |size, rng|
        generated_input = self.call(size, rng)
        initialized_generator = generator_proc.call(generated_input)
        initialized_generator.call(size, rng)
      end,
      # First shrink inner generator
      # and afterwards, shrink outer (and shrink inner again for each of the calls).
      shrink: proc do |val|
        initialized_generator = generator_proc.call(val)

        simple_shrink_candidates = initialized_generator.shrink
        complex_shrink_candidates = self.shrink.flat_map do |val|
          generator_proc.call(val).shrink
        end

        [simple_shrink_candidates, complex_shrink_candidates].lazy.flat_map(&:lazy)
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
    # res << 0 unless val.zero?

    halvings = Helper.scanl(val) { |x| x / 2 }
                 .take_while { |x| !x.zero? }
                 .map { |x| val - x }

    [res, halvings].lazy.flat_map(&:lazy)
  end

  def choose(range)
    Generator.new(
      generate: proc { |_size, rng| rng.rand(range) },
      shrink: proc { |val| integer_shrink}
    )
  end

  def integer
    Generator.new(
      generate: proc { |size, rng| rng.rand(-size..size) },
      shrink: proc { |val| integer_shrink}
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
