require 'stringio'

require 'prop_check/property/check_evaluator'
module PropCheck
  class Property
    @@default_settings = {
      verbose: false,
      n_runs: 1_000,
      max_generate_attempts: 10_000,
      max_shrink_steps: 10_000
    }

    def self.forall(name = '', **bindings, &block)

      property = new(name, bindings)

      return property.check(&block) if block_given?

      property
    end

    attr_reader :name, :bindings, :condition, :settings
    def initialize(name = '', **bindings)
      raise ArgumentError, 'No bindings specified!' if bindings.empty?

      @name = name
      @bindings = bindings
      @condition = -> { true }
      @settings = @@default_settings
    end

    def with_settings(**settings, &block)
      @settings = @settings.merge(settings)

      return self.check(&block) if block_given?

      self
    end

    def where(&new_condition)
      original_condition = @condition.dup
      @condition = -> { instance_exec(&original_condition) && instance_exec(&new_condition) }

      self
    end

    def check(&block)
      binding_generator = PropCheck::Generators.fixed_hash(bindings)

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
      return if n_runs >= @settings[:n_runs]

      raise GeneratorExhaustedError, """
        Could not perform `n_runs = #{@settings[:n_runs]}` runs,
        (exhausted #{@settings[:max_generate_attempts]} tries)
        because too few generator results were adhering to
        the `where` condition.

        Try refining your generators instead.
        """
    end

    private def check_attempt(generator_result, n_successful, &block)
      CheckEvaluator.new(generator_result.root, &block).call
    rescue UserError => e
      p "WE HAVE A USER ERROR"
      p e
      raise

    # immediately stop (without shrinnking) for when the app is asked
    # to close by outside intervention
    rescue SignalException, SystemExit
      raise

    # We want to capture _all_ exceptions (even low-level ones) here,
    # so we can shrink to find their cause.
    # don't worry: they all get reraised
    rescue Exception => e
      output = show_problem_output(e, generator_result, n_successful, &block)
      output_string = output.is_a?(StringIO) ? output.string : e.message

      raise e, output_string, e.backtrace
    end

    private def attempts_enumerator(binding_generator)

      rng = Random::DEFAULT
      n_runs = 0
      size = 1
      (0...@settings[:max_generate_attempts])
        .lazy
        .map { binding_generator.generate(size, rng) }
        .select { |val| CheckEvaluator.new(val.root, &@condition).call }
        .map do |result|
          n_runs += 1
          size += 1

          result
        end
        .take_while { n_runs <= @settings[:n_runs] }
    end

    private def show_problem_output(problem, generator_results, n_successful, &block)
      output = @settings[:verbose] ? STDOUT : StringIO.new
      output = pre_output(output, n_successful, generator_results.root, problem)
      shrunken_result, shrunken_exception, n_shrink_steps = shrink2(generator_results, output, &block)
      output = post_output(output, n_shrink_steps, shrunken_result, shrunken_exception)

      output
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
      lazy_tree_hash.map do |name, val|
        "#{name} = #{val.inspect}"
      end.join(", ")
    end

    private def shrink2(bindings_tree, io, &fun)
      io.puts 'Shrinking...' if @settings[:verbose]
      problem_child = bindings_tree
      siblings = problem_child.children.lazy
      parent_siblings = nil
      problem_exception = nil
      shrink_steps = 0
      (0..@settings[:max_shrink_steps]).each do
        begin
          sibling = siblings.next
        rescue StopIteration
          break if parent_siblings.nil?

          siblings = parent_siblings.lazy
          parent_siblings = nil
          next
        end

        shrink_steps += 1
        io.print '.' if @settings[:verbose]

        begin
          CheckEvaluator.new(sibling.root, &fun).call
        rescue Exception => problem
          problem_child = sibling
          parent_siblings = siblings
          siblings = problem_child.children.lazy
          problem_exception = problem
        end
      end

      io.puts "(Note: Exceeded #{@settings[:max_shrink_steps]} shrinking steps, the maximum.)" if shrink_steps >= @settings[:max_shrink_steps]

      [problem_child.root, problem_exception, shrink_steps]
    end
  end
end
