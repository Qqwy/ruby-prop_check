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
    @@default_rng =
      # Backwards compatibility: Random::DEFAULT is deprecated in Ruby 3.x
      # but required in Ruby 2.x and 1.x
      if RUBY_VERSION.to_i >= 3
        Random
      else
        Random::DEFAULT
      end
    @@max_consecutive_attempts = 100
    @@default_kwargs = { size: @@default_size, rng: @@default_rng,
                         max_consecutive_attempts: @@max_consecutive_attempts }

    ##
    # Being a special kind of Proc, a Generator wraps a block.
    def initialize(&block)
      @block = block
    end

    ##
    # Given a `size` (integer) and a random number generator state `rng`,
    # generate a LazyTree.
    def generate(**kwargs)
      kwargs = @@default_kwargs.merge(kwargs)
      max_consecutive_attempts = kwargs[:max_consecutive_attempts]

      (0..max_consecutive_attempts).each do
        res = @block.call(**kwargs)
        next if res.root == :"_PropCheck.filter_me"

        return res
      end

      raise Errors::GeneratorExhaustedError, ''"
      Exhausted #{max_consecutive_attempts} consecutive generation attempts.

      Probably too few generator results were adhering to a `where` condition.
      "''
    end

    ##
    # Generates a value, and only return this value
    # (drop information for shrinking)
    #
    #   >> Generators.integer.call(size: 1000, rng: Random.new(42))
    #   => 126
    def call(**kwargs)
      generate(**@@default_kwargs.merge(kwargs)).root
    end

    ##
    # Returns `num_of_samples` values from calling this Generator.
    # This is mostly useful for debugging if a generator behaves as you intend it to.
    def sample(num_of_samples = 10, **kwargs)
      num_of_samples.times.map do
        call(**@@default_kwargs.merge(kwargs))
      end
    end

    ##
    # Creates a 'constant' generator that always returns the same value,
    # regardless of `size` or `rng`.
    #
    # Keen readers may notice this as the Monadic 'pure'/'return' implementation for Generators.
    #
    #   >> Generators.integer.bind { |a| Generators.integer.bind { |b| Generator.wrap([a , b]) } }.call(size: 100, rng: Random.new(42))
    #   => [2, 79]
    def self.wrap(val)
      Generator.new { LazyTree.wrap(val) }
    end

    ##
    # Create a generator whose implementation depends on the output of another generator.
    # this allows us to compose multiple generators.
    #
    # Keen readers may notice this as the Monadic 'bind' (sometimes known as '>>=') implementation for Generators.
    #
    #   >> Generators.integer.bind { |a| Generators.integer.bind { |b| Generator.wrap([a , b]) } }.call(size: 100, rng: Random.new(42))
    #   => [2, 79]
    def bind(&generator_proc)
      # Generator.new do |size, rng|
      #   outer_result = generate(size, rng)
      #   outer_result.map do |outer_val|
      #     inner_generator = generator_proc.call(outer_val)
      #     inner_generator.generate(size, rng)
      #   end.flatten
      # end
      Generator.new do |**kwargs|
        outer_result = generate(**kwargs)
        outer_result.bind do |outer_val|
          inner_generator = generator_proc.call(outer_val)
          inner_generator.generate(**kwargs)
        end
      end
    end

    ##
    # Creates a new Generator that returns a value by running `proc` on the output of the current Generator.
    #
    #   >> Generators.choose(32..128).map(&:chr).call(size: 10, rng: Random.new(42))
    #   => "S"
    def map(&proc)
      Generator.new do |**kwargs|
        result = generate(**kwargs)
        result.map(&proc)
      end
    end

    ##
    # Turns a generator returning `x` into a generator returning `[x, config]`
    # where `config` is the current `PropCheck::Property::Configuration`.
    # This can be used to inspect the configuration inside a `#map` or `#where`
    # and act on it.
    #
    #  >> example_config = PropCheck::Property::Configuration.new(default_epoch: Date.new(2022, 11, 22))
    #  >> generator = Generators.choose(0..100).with_config.map { |int, conf| Date.jd(conf[:default_epoch].jd + int) }
    #  >> generator.call(size: 10, rng: Random.new(42), config: example_config)
    #  => Date.new(2023, 01, 12)
    def with_config
      Generator.new do |**kwargs|
        result = generate(**kwargs)
        result.map { |val| [val, kwargs[:config]] }
      end
    end

    ##
    # Creates a new Generator that only produces a value when the block `condition` returns a truthy value.
    def where(&condition)
      map do |result|
        # if condition.call(*result)
        if PropCheck::Helper.call_splatted(result, &condition)
          result
        else
          :"_PropCheck.filter_me"
        end
      end
    end

    ##
    # Resizes the generator to either grow faster or smaller than normal.
    #
    # `proc` takes the current size as input and is expected to return the new size.
    # a size should always be a nonnegative integer.
    #
    #    >> Generators.integer.resize{}
    def resize(&proc)
      Generator.new do |size:, **other_kwargs|
        new_size = proc.call(size)
        generate(**other_kwargs, size: new_size)
      end
    end
  end
end
