module PropCheck
  ##
  # A `Generator` is a special kind of 'proc' that,
  # given a size an random number generator state,
  # will generate a (finite) LazyTree of output values:
  #
  # The root of this tree is the value to be used during testing,
  # and the children are 'smaller' values related to the root,
  # to be used during the shrinking phase.
  class Generator
    @@default_size = 10
    @@default_rng = Random.new

    ##
    # Being a special kind of Proc, a Generator wraps a block.
    def initialize(&block)
      @block = block
    end

    ##
    # Given a `size` (integer) and a random number generator state `rng`,
    # generate a LazyTree.
    def generate(size = @@default_size, rng = @@default_rng)
      @block.call(size, rng)
    end

    ##
    # Generates a value, and only return this value
    # (drop information for shrinking)
    #
    #   >> Generators.integer.call(1000, Random.new(42))
    #   => 126
    def call(size = @@default_size, rng = @@default_rng)
      generate(size, rng).root
    end

    ##
    # Returns `num_of_samples` values from calling this Generator.
    # This is mostly useful for debugging if a generator behaves as you intend it to.
    def sample(num_of_samples = 10, size: @@default_size, rng: @@default_rng)
      num_of_samples.times.map do
        call(size, rng)
      end
    end

    ##
    # Creates a 'constant' generator that always returns the same value,
    # regardless of `size` or `rng`.
    #
    # Keen readers may notice this as the Monadic 'pure'/'return' implementation for Generators.
    #
    #   >> Generators.integer.bind { |a| Generators.integer.bind { |b| Generator.wrap([a , b]) } }.call(100, Random.new(42))
    #   => [2, 79]
    def self.wrap(val)
      Generator.new { |_size, _rng| LazyTree.wrap(val) }
    end

    ##
    # Create a generator whose implementation depends on the output of another generator.
    # this allows us to compose multiple generators.
    #
    # Keen readers may notice this as the Monadic 'bind' (sometimes known as '>>=') implementation for Generators.
    #
    #   >> Generators.integer.bind { |a| Generators.integer.bind { |b| Generator.wrap([a , b]) } }.call(100, Random.new(42))
    #   => [2, 79]
    def bind(&generator_proc)
      # Generator.new do |size, rng|
      #   outer_result = generate(size, rng)
      #   outer_result.map do |outer_val|
      #     inner_generator = generator_proc.call(outer_val)
      #     inner_generator.generate(size, rng)
      #   end.flatten
      # end
      Generator.new do |size, rng|
        outer_result = generate(size, rng)
        outer_result.bind do |outer_val|
          inner_generator = generator_proc.call(outer_val)
          inner_generator.generate(size, rng)
        end
      end
    end

    ##
    # Creates a new Generator that returns a value by running `proc` on the output of the current Generator.
    #
    #   >> Generators.choose(32..128).map(&:chr).call(10, Random.new(42))
    #   => "S"
    def map(&proc)
      Generator.new do |size, rng|
        result = self.generate(size, rng)
        result.map(&proc)
      end
    end
  end
end
