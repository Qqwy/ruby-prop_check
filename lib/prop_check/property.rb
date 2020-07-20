require 'stringio'
require "awesome_print"

require 'prop_check/property/configuration'
require 'prop_check/property/check_evaluator'
module PropCheck
  ##
  # Run properties
  class Property

    ##
    # Call this with a keyword argument list of (symbol => generators) and a block.
    # The block will then be executed many times, with the respective symbol names
    # being defined as having a single generated value.
    #
    # If you do not pass a block right away,
    # a Property object is returned, which you can call the other instance methods
    # of this class on before finally passing a block to it using `#check`.
    # (so `forall(a: Generators.integer) do ... end` and forall(a: Generators.integer).check do ... end` are the same)
    def self.forall(*bindings, &block)

      property = new(*bindings)

      return property.check(&block) if block_given?

      property
    end

    ##
    # Returns the default configuration of the library as it is configured right now
    # for introspection.
    #
    # For the configuration of a single property, check its `configuration` instance method.
    # See PropCheck::Property::Configuration for more info on available settings.
    def self.configuration
      @configuration ||= Configuration.new
    end

    ##
    # Yields the library's configuration object for you to alter.
    # See PropCheck::Property::Configuration for more info on available settings.
    def self.configure
      yield(configuration)
    end

    attr_reader :bindings, :condition

    def initialize(*bindings)
      raise ArgumentError, 'No bindings specified!' if bindings.empty?

      @bindings = bindings
      @condition = proc { true }
      @config = self.class.configuration
    end

    ##
    # Returns the configuration of this property
    # for introspection.
    #
    # See PropCheck::Property::Configuration for more info on available settings.
    def configuration
      @config
    end

    ##
    # Allows you to override the configuration of this property
    # by giving a hash with new settings.
    #
    # If no other changes need to occur before you want to check the property,
    # you can immediately pass a block to this method.
    # (so `forall(a: Generators.integer).with_config(verbose: true) do ... end` is the same as `forall(a: Generators.integer).with_config(verbose: true).check do ... end`)
    def with_config(**config, &block)
      @config = @config.merge(config)

      return self.check(&block) if block_given?

      self
    end

    ##
    # filters the generator using the  given `condition`.
    # The final property checking block will only be run if the condition is truthy.
    #
    # If wanted, multiple `where`-conditions can be specified on a property.
    # Be aware that if you filter away too much generated inputs,
    # you might encounter a GeneratorExhaustedError.
    # Only filter if you have few inputs to reject. Otherwise, improve your generators.
    def where(&condition)
      original_condition = @condition.dup
      @condition = proc do |*args|
        # instance_exec(&original_condition) && instance_exec(&condition)
        original_condition.call(*args) && condition.call(*args)
      end

      self
    end

    ##
    # Checks the property (after settings have been altered using the other instance methods in this class.)
    def check(&block)
      binding_generator = PropCheck::Generators.tuple(*@bindings)

      n_runs = 0
      n_successful = 0

      # Loop stops at first exception
      attempts_enumerator(binding_generator).each do |generator_result|
        n_runs += 1
        check_attempt(generator_result, n_successful, &block)
        n_successful += 1
      end

      ensure_not_exhausted!(n_runs)
    end

    private def ensure_not_exhausted!(n_runs)
      return if n_runs >= @config.n_runs

      raise Errors::GeneratorExhaustedError, """
        Could not perform `n_runs = #{@config.n_runs}` runs,
        (exhausted #{@config.max_generate_attempts} tries)
        because too few generator results were adhering to
        the `where` condition.

        Try refining your generators instead.
        """
    end

    private def check_attempt(generator_result, n_successful, &block)
      # CheckEvaluator.new(generator_result.root, &block).call
      block.call(*generator_result.root)

    # immediately stop (without shrinnking) for when the app is asked
    # to close by outside intervention
    rescue SignalException, SystemExit
      raise

    # We want to capture _all_ exceptions (even low-level ones) here,
    # so we can shrink to find their cause.
    # don't worry: they all get reraised
    rescue Exception => e
      output, shrunken_result, shrunken_exception, n_shrink_steps = show_problem_output(e, generator_result, n_successful, &block)
      output_string = output.is_a?(StringIO) ? output.string : e.message

      e.define_singleton_method :prop_check_info do
        {
          original_input: generator_result.root,
          original_exception_message: e.message,
          shrunken_input: shrunken_result,
          shrunken_exception: shrunken_exception,
          n_successful: n_successful,
          n_shrink_steps: n_shrink_steps
        }
      end

      raise e, output_string, e.backtrace
    end

    private def attempts_enumerator(binding_generator)

      rng = Random::DEFAULT
      n_runs = 0
      size = 1
      (0...@config.max_generate_attempts)
        .lazy
        .map { binding_generator.generate(size, rng) }
        .reject { |val| val.root == :"_PropCheck.filter_me" }
        .select { |val| @condition.call(*val.root) }
        .map do |result|
          n_runs += 1
          size += 1

          result
        end
        .take_while { n_runs <= @config.n_runs }
    end

    private def show_problem_output(problem, generator_results, n_successful, &block)
      output = @config.verbose ? STDOUT : StringIO.new
      output = pre_output(output, n_successful, generator_results.root, problem)
      shrunken_result, shrunken_exception, n_shrink_steps = shrink(generator_results, output, &block)
      output = post_output(output, n_shrink_steps, shrunken_result, shrunken_exception)

      [output, shrunken_result, shrunken_exception, n_shrink_steps]
    end

    private def pre_output(output, n_successful, generated_root, problem)
      output.puts ""
      output.puts "(after #{n_successful} successful property test runs)"
      output.puts "Failed on: "
      output.puts "`#{print_roots(generated_root)}`"
      output.puts ""
      output.puts "Exception message:\n---\n#{problem}"
      output.puts "---"
      output.puts ""

      output
    end

    private def post_output(output, n_shrink_steps, shrunken_result, shrunken_exception)
      output.puts ''
      output.puts "Shrunken input (after #{n_shrink_steps} shrink steps):"
      output.puts "`#{print_roots(shrunken_result)}`"
      output.puts ""
      output.puts "Shrunken exception:\n---\n#{shrunken_exception}"
      output.puts "---"
      output.puts ""

      output
    end

    private def print_roots(lazy_tree_hash)
      # lazy_tree_hash.map do |name, val|
      #   "#{name} = #{val.inspect}"
      # end.join(", ")
      lazy_tree_hash.ai
    end

    private def shrink(bindings_tree, io, &fun)
      io.puts 'Shrinking...' if @config.verbose
      problem_child = bindings_tree
      siblings = problem_child.children.lazy
      parent_siblings = nil
      problem_exception = nil
      shrink_steps = 0
      (0..@config.max_shrink_steps).each do
        begin
          sibling = siblings.next
        rescue StopIteration
          break if parent_siblings.nil?

          siblings = parent_siblings.lazy
          parent_siblings = nil
          next
        end

        shrink_steps += 1
        io.print '.' if @config.verbose

        begin
          # CheckEvaluator.new(sibling.root, &fun).call
          fun.call(*sibling.root)
        rescue Exception => e
          problem_child = sibling
          parent_siblings = siblings
          siblings = problem_child.children.lazy
          problem_exception = e
        end
      end

      io.puts "(Note: Exceeded #{@config.max_shrink_steps} shrinking steps, the maximum.)" if shrink_steps >= @config.max_shrink_steps

      [problem_child.root, problem_exception, shrink_steps]
    end
  end
end
