require 'stringio'

require 'prop_check/property/check_evaluator'
module PropCheck
  class Property
    @@default_settings = {
      verbose: false,
      n_runs: 1_000,
      max_generate_attempts: 10_000
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

    def with_settings(**settings)
      @settings = @settings.merge(settings)

      self
    end

    def adhering_to(&new_condition)
      original_condition = @condition.dup
      @condition = -> { instance_exec(&original_condition) && instance_exec(&new_condition) }

      self
    end

    def check(&block)
      binding_generator = PropCheck::Generators.fixed_hash(bindings)

      n_runs = 0
      n_successful = 0

      attempts_enumerator(binding_generator).each do |generator_result|
        # Loop stops at first exception
        # since it is reraised
        n_runs += 1
        begin
          CheckEvaluator.new(generator_result.root, &block).call
          n_successful += 1
        rescue PropCheck::UserError => e
          raise e
        rescue Exception => problem
          output = show_problem_output(problem, generator_result, n_successful, &block)
          output_string =
            if output.is_a? StringIO
              output.string
            else
              problem.message
            end

          raise problem, output_string, problem.backtrace
        end
      end

      if n_runs < @settings[:n_runs]
        raise GeneratorExhausted, """
        Could not perform `n_runs = #{@settings[:n_runs]}` runs,
        (exhausted #{@settings[:max_generate_attempts]} tries)
        because too few generator results were adhering to
        the `adhering_to` condition.

        Try refining your generators instead.
        """
      end
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
      shrunken_result, shrunken_exception, n_shrink_steps = shrink(generator_results, output, &block)
      output = post_output(output, n_shrink_steps, shrunken_result, shrunken_exception)

      output
    end

    private def pre_output(output, n_successful, generated_root, problem)
      output.puts ""
      output.puts "FAILURE after #{n_successful} successful test runs. Failed on:"
      output.puts "`#{print_roots(generated_root)}`"
      output.puts ""
      output.puts "Exception message: #{problem}"
      output.puts ""
      output.puts "Shrinking"

      output
    end

    private def post_output(output, n_shrink_steps, shrunken_result, shrunken_exception)
      output.puts ''
      output.puts "Shrunken input after #{n_shrink_steps} steps:"
      output.puts "`#{print_roots(shrunken_result)}`"
      output.puts ""
      output.puts "Shrunken exception: #{shrunken_exception}"
      output.puts ""

      output
    end

    private def print_roots(lazy_tree_hash)
      lazy_tree_hash.map do |name, val|
        "#{name} = #{val.inspect}"
      end.join(", ")
    end

    private def shrink(bindings_tree, output, &block)
      problem_child = bindings_tree
      problem_exception = nil
      num_shrink_steps = 0
      10_000.times do
        next_problem_child, next_problem_exception, child_shrink_steps = shrink_step(problem_child, output, &block)

        break if next_problem_child.nil?

        problem_child = next_problem_child
        problem_exception = next_problem_exception
        num_shrink_steps += child_shrink_steps
      end

      [problem_child.root, problem_exception, num_shrink_steps]
    end

    private def shrink_step(bindings_tree, output, &block)
      shrink_steps = 0
      bindings_tree.children.each do |child|
        shrink_steps += 1
        output.print '.'
        begin
          CheckEvaluator.new(child.root, &block).call
        rescue Exception => problem
          return [child, problem, shrink_steps]
        end
      end

      [nil, nil, shrink_steps]
    end


    # def shrink2(bindings_tree, io, &fun)
    #   problem_child = bindings_tree
    #   siblings = problem_child.children.lazy
    #   parent_siblings = nil
    #   problem_exception = nil
    #   shrink_steps = 0
    #   10_000.times do
    #     # next_problem_child, siblings, next_problem_exception, child_shrink_steps = shrink_step2(siblings, io, &fun)

    #     # if siblings.empty?
    #     begin
    #       sibling = siblings.next
    #     rescue StopIteration
    #       break if parent_siblings.nil?
    #       siblings = parent_siblings.lazy
    #       parent_siblings = nil
    #       next
    #     end
    #     # end

    #     shrink_steps += 1
    #     begin
    #       CheckEvaluator.new(sibling.root, &fun).call
    #     rescue Exception => problem
    #       p sibling.root
    #       problem_child = sibling
    #       parent_siblings = siblings
    #       siblings = problem_child.children.lazy
    #       problem_exception = problem
    #     end
    #   end

    #   [problem_child.root, problem_exception, shrink_steps]
    # end

    # def shrink_step2(siblings, io, &fun)
    #   shrink_steps = 0
    #   loop do
    #     begin
    #       sibling = siblings.next
    #     rescue StopIteration
    #       break
    #     end

    #     shrink_steps += 1
    #     io.print "."
    #     begin
    #       # p sibling.root
    #       CheckEvaluator.new(sibling.root, &fun).call
    #     rescue Exception => problem
    #       return [sibling, siblings, problem, shrink_steps]
    #     end
    #   end

    #   return [nil, [], nil, shrink_steps]
    # end
  end
end
