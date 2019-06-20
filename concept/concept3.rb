require 'stringio'

##
# Helper functions that have no other place to live
module Helper
  ##
  # Creates a (potentially lazy) Enumerator
  # starting with `elem`
  # with each consecutive element obtained
  # by calling `operation` on the previous element.
  #
  # >> Helper.scanl(0, &:next).take(10).force
  # => [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
  # >> Helper.scanl([0, 1]) { |curr, next_elem| [next_elem, curr + next_elem] }.map(&:first).take(10).force
  # => [0, 1, 1, 2, 3, 5, 8, 13, 21, 34]
  def self.scanl(elem, &operation)
    Enumerator.new do |yielder|
      acc = elem
      loop do
        # p acc
        yielder << acc
        acc = operation.call(acc)
      end
    end.lazy
  end
end

##
# A Rose tree with the root being eager,
# and the children computed lazily, on demand.
LazyTree = Struct.new(:root, :children) do
  ##
  # The children default to an empty lazy list.
  def children
    (self[:children] || [].lazy)
  end

  ##
  # Maps `block` eagerly over `root` and lazily over `children`, returning a new LazyTree as result.
  #
  # >> LazyTree.new(1, [LazyTree.new(2, [LazyTree.new(3)]), LazyTree.new(4)]).map(&:next)
  # => LazyTree.new(2, [LazyTree.new(3, [LazyTree.new(4)]), LazyTree.new(5)]).map(&:next)
  def map(&block)
    LazyTree.new(block.call(root), children.map { |child_tree| child_tree.map(&block) })
  end

  ##
  # Turns a tree of trees
  # in a single flattened tree, with subtrees that are closer to the root
  # and the left subtree earlier in the list of children.
  def flatten
    root_tree = root
    root_root = root_tree.root
    root_children = root_tree.children
    child_trees = children

    LazyTree.new(root_root, [root_children, child_trees.map(&:flatten)].lazy.flat_map(&:lazy))
  end

  ##
  # Turns a LazyTree in a long lazy enumerable, with the root first followed by its children
  # (and the first children's result before later children; i.e. a depth-first traversal.)
  #
  # Be aware that this lazy enumerable is potentially infinite,
  # possibly uncountably so.
  #
  # >> LazyTree.new(1, [LazyTree.new(2, [LazyTree.new(3)]), LazyTree.new(4)]).each.force
  # => [1, 2, 3, 4]
  def each#(&block)
    res = [[self.root], self.children.flat_map(&:each)].lazy.flat_map(&:lazy)
    # res = res.map(&block) if block_given?
    res
  end

  ##
  # Fully evaluate the LazyTree into an eager array, with the root first followed by its children
  # (and the first children's result before later children; i.e. a depth-first traversal.)
  #
  # Be aware that calling this might make Ruby attempt to evaluate an infinite collection.
  # Therefore, it is mostly useful for debugging; in production you probably want to use
  # the other mechanisms this class provides..
  #
  # >> LazyTree.new(1, [LazyTree.new(2, [LazyTree.new(3)]), LazyTree.new(4)]).to_a
  # => [1, 2, 3, 4]
  def to_a
    each.force
  end
end

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
  # >> Generators.integer.call(1000, Random.new(42))
  # => 126
  def call(size = @@default_size, rng = @@default_rng)
    generate(size, rng).root
  end

  ##
  # Creates a 'constant' generator that always returns the same value,
  # regardless of `size` or `rng`.
  #
  # Keen readers may notice this as the Monadic 'pure'/'return' implementation for Generators.
  #
  # >> Generators.integer.bind { |a| Generators.integer.bind { |b| Generator.wrap([a , b]) } }.call(100, Random.new(42))
  # => [2, 79]
  def self.wrap(val)
    Generator.new { |_size, _rng| LazyTree.new(val, []) }
  end

  ##
  # Create a generator whose implementation depends on the output of another generator.
  # this allows us to compose multiple generators.
  #
  # Keen readers may notice this as the Monadic 'bind' (sometimes known as '>>=') implementation for Generators.
  #
  # >> Generators.integer.bind { |a| Generators.integer.bind { |b| Generator.wrap([a , b]) } }.call(100, Random.new(42))
  # => [2, 79]
  def bind(&generator_proc)
    Generator.new do |size, rng|
      outer_result = generate(size, rng)
      outer_result.map do |outer_val|
        inner_generator = generator_proc.call(outer_val)
        inner_generator.generate(size, rng)
      end.flatten
    end
  end

  ##
  # Creates a new Generator that returns a value by running `proc` on the output of the current Generator.
  #
  # >> Generators.choose(32..128).map(&:chr).call(10, Random.new(42))
  # => "S"
  def map(&proc)
    Generator.new do |size, rng|
      result = self.generate(size, rng)
      result.map(&proc)
    end
  end
end


##
#
module Generators

  def constant(val)
    Generator.wrap(val)
  end

  private def integer_shrink(val)
    return [] if val.zero?

    halvings = Helper.scanl(val) { |x| (x / 2.0).truncate }
                 .take_while { |x| !x.zero? }
                 .map { |x| val - x }
                 .map { |x| LazyTree.new(x) }

    if val.abs > val
      [LazyTree.new(val.abs, halvings)].lazy
    else
      halvings
    end
  end

  def choose(range)
    Generator.new do |_size, rng|
      val = rng.rand(range)
      LazyTree.new(val, integer_shrink(val))
    end
  end

  def integer
    Generator.new do |size, rng|
      val = rng.rand(-size..size)
      LazyTree.new(val, integer_shrink(val))
    end
  end

  def nonnegative_integer
    integer.map { |x| x.abs }
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

  def one_of(*choices)
    choose(choices.length).bind do |index|
      choices[index]
    end
  end

  def frequency(frequencies)
    choices = frequencies.reduce([]) do |acc, elem|
      freq, val = elem
      acc + ([val] * freq)
    end
    one_of(*choices)
  end

  def tuple(*generators)
    # generators.map(&:bind).reduce do ||
    # end
    generators.reverse.reduce(Generator.wrap([])) do |acc, generator|
      generator.bind do |val|
        acc.map { |x| x << val }
      end
    end
    # args.reduce(Generator.wrap([])) do |acc, generator|
    #   acc.map
    # end
    # args.reduce([]) do |acc, generator|
    #   generator.bind do |arg|
    #     Generator.wrap(acc << arg)
    #   end
    # end
  end
end

class PropertyFailure < StandardError
end

class PropertyCheckEvaluator
  # A wrapper class that implements the 'Cloaker' concept
  # which allows us to refer to variables set in 'bindings',
  # while still being able to access things that are only in scope
  # in the creator of '&block'.
  #
  # This allows us to bind the variables specified in `bindings`
  # one way during checking and another way during shrinking.
  def initialize(bindings, &block)
    @caller = eval 'self', block.binding, __FILE__, __LINE__
    @block = block
    define_named_instance_methods(bindings)
  end

  def call()
    instance_exec(&@block)
  end

  private def define_named_instance_methods(results)
    results.each do |name, result|
      define_method(name) { result }
    end
  end

  def method_missing(method, *args, &block)
    @caller.__send__(method, *args, &block)
  end

  def respond_to?(*args)
    super || @caller.respond_to?(*args)
  end
end


def forall(**bindings, &block)

  # Turns a hash of generators
  # into a generator of hashes :D
  binding_generator = tuple(*bindings.map { |key, generator| generator.map { |val| [key, val] } }).map { |val| val.to_h }

  rng = Random::DEFAULT
  n_successful = 0
  generator_results = nil
  begin
    (1..1000).each do |size|
      generator_results = binding_generator.generate(size, rng)
      PropertyCheckEvaluator.new(generator_results.root, &block).call()
      n_successful += 1
    end
  rescue Exception => problem
    output = StringIO.new
    output.puts ""
    output.puts "FAILURE after #{n_successful} successful tests. Failed on:"
    output.puts "`#{print_roots(generator_results.root)}`"
    output.puts ""
    output.puts "Exception: #{problem.full_message}"
    output.puts "Shrinking..."
    shrunken_result, shrunken_exception, num_shrink_steps = shrink(generator_results, &block)
    output.puts "Shrunken input after #{num_shrink_steps} steps:"
    output.puts "`#{print_roots(shrunken_result)}`"
    output.puts ""
    output.puts "Shrunken exception: #{shrunken_exception.full_message}"

    raise PropertyFailure, output.string
  end
end

def print_roots(lazy_tree_hash)
  lazy_tree_hash.map do |name, val|
    "#{name} = #{val.inspect}"
  end.join(", ")
end

def shrink(bindings_tree, &block)
  problem_child = bindings_tree
  problem_exception = nil
  num_shrink_steps = 0
  loop do
    next_problem_child, next_problem_exception, child_shrink_steps = shrink_step(problem_child, &block)

    break if next_problem_child.nil?

    problem_child = next_problem_child
    problem_exception = next_problem_exception
    num_shrink_steps += child_shrink_steps
  end

  [problem_child.root, problem_exception, num_shrink_steps]
end

def shrink_step(bindings_tree, &block)
  shrink_steps = 0
  bindings_tree.children.each do |child|
    shrink_steps += 1
    begin
      PropertyCheckEvaluator.new(child.root, &block).call()
    rescue Exception => problem
      return [child, problem, shrink_steps]
    end
  end

  [nil, nil, shrink_steps]
end

include Generators

forall x: integer, z: float, y: nonnegative_integer do
  # puts x
  # puts y
  # puts z

  # if y == 42
  #   raise "Boom!"
  # end

  x > y == z
end
