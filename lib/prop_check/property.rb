require 'stringio'

require 'prop_check/property/check_evaluator'
module PropCheck
  module Property
    extend self
    def forall(**bindings, &block)

      # Turns a hash of generators
      # into a generator of hashes :D
      binding_generator = PropCheck::Generators.fixed_hash(bindings)

      rng = Random::DEFAULT
      n_successful = 0
      generator_results = nil
      begin
        (1..1000).each do |size|
          generator_results = binding_generator.generate(size, rng)
          CheckEvaluator.new(generator_results.root, &block).call()
          n_successful += 1
        end
      rescue Exception => problem
        output = StringIO.new
        output.puts ""
        output.puts "FAILURE after #{n_successful} successful test runs. Failed on:"
        output.puts "`#{print_roots(generator_results.root)}`"
        output.puts ""
        output.puts "Exception message: #{problem}"
        output.puts ""
        output.puts "Shrinking"
        shrunken_result, shrunken_exception, num_shrink_steps = shrink2(generator_results, output, &block)
        output.puts ''
        output.puts "Shrunken input after #{num_shrink_steps} steps:"
        output.puts "`#{print_roots(shrunken_result)}`"
        output.puts ""
        output.puts "Shrunken exception: #{shrunken_exception}"
        output.puts ""

        raise problem, output.string, problem.backtrace
      end
    end

    def print_roots(lazy_tree_hash)
      lazy_tree_hash.map do |name, val|
        "#{name} = #{val.inspect}"
      end.join(", ")
    end

    def shrink(bindings_tree, output, &block)
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

    def shrink2(bindings_tree, io, &fun)
      problem_child = bindings_tree
      siblings = problem_child.children.lazy
      parent_siblings = nil
      problem_exception = nil
      shrink_steps = 0
      10_000.times do
        # next_problem_child, siblings, next_problem_exception, child_shrink_steps = shrink_step2(siblings, io, &fun)

        # if siblings.empty?
        begin
          sibling = siblings.next
        rescue StopIteration
          break if parent_siblings.nil?
          siblings = parent_siblings.lazy
          parent_siblings = nil
          next
        end
        # end

        shrink_steps += 1
        begin
           p sibling.root
          CheckEvaluator.new(sibling.root, &fun).call
        rescue Exception => problem
          p "PROBLEM:"
          p problem
          problem_child = sibling
          parent_siblings = siblings
          siblings = problem_child.children.lazy
          problem_exception = problem
        end
      end

      [problem_child.root, problem_exception, shrink_steps]
    end

    def shrink_step2(siblings, io, &fun)
      shrink_steps = 0
      loop do
        begin
          sibling = siblings.next
        rescue StopIteration
          break
        end

        shrink_steps += 1
        io.print "."
        begin
          # p sibling.root
          CheckEvaluator.new(sibling.root, &fun).call
        rescue Exception => problem
          return [sibling, siblings, problem, shrink_steps]
        end
      end

      return [nil, [], nil, shrink_steps]
    end

    def shrink_step(bindings_tree, output, &block)
      shrink_steps = 0
      bindings_tree.children.each do |child|
        shrink_steps += 1
        output.print '.'
        begin
          # p child.root
          CheckEvaluator.new(child.root, &block).call
        rescue Exception => problem
          return [child, problem, shrink_steps]
        end
      end

      [nil, nil, shrink_steps]
    end
  end
end
