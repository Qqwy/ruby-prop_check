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
# Contains common generators.
# Use this module by including it in the class (e.g. in your test suite)
# where you want to use them.
module Generators
  ##
  # Always returns the same value, regardless of `size` or `rng` (random number generator state)
  #
  # >> Generators.constant(10)
  def constant(val)
    Generator.wrap(val)
  end

  private def integer_shrink(val)
    # 0 cannot shrink further
    return [] if val.zero?

    # Numbers are shrunken by
    # subtracting themselves, their half, quarter, eight, ... (rounded towards zero!) from themselves, until the number itself is reached.
    # So: for 20 we have [0, 10, 15, 18, 19, 20]
    halvings =
      Helper.scanl(val) { |x| (x / 2.0).truncate }
            .take_while { |x| !x.zero? }
            .map { |x| val - x }
            .map { |x| LazyTree.new(x) }

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
  # >> r = Random.new(42); 10.times.map { Generators.choose(0..5).call(10, r) }
  # => [3, 4, 2, 4, 4, 1, 2, 2, 2, 4]
  # >> r = Random.new(42); 10.times.map { Generators.choose(0..5).call(20000, r) }
  # => [3, 4, 2, 4, 4, 1, 2, 2, 2, 4]
  def choose(range)
    Generator.new do |_size, rng|
      val = rng.rand(range)
      LazyTree.new(val, integer_shrink(val))
    end
  end

  ##
  # A random integer which scales with `size`.
  # Integers start small (around 0)
  # and become more extreme (both higher and lower, negative) when `size` increases.
  #
  # >> Generators.integer.call(2, Random.new(42))
  # => 2
  # >> Generators.integer.call(10000, Random.new(42))
  # => 5795
  # >> r = Random.new(42); 10.times.map { Generators.integer.call(20000, r) }
  # => [-4205, -19140, 18158, -8716, -13735, -3150, 17194, 1962, -3977, -18315]
  def integer
    Generator.new do |size, rng|
      val = rng.rand(-size..size)
      LazyTree.new(val, integer_shrink(val))
    end
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

  private def fraction(a, b, c)
    a.to_f + b.to_f / (c.to_f.abs + 1.0)
  end

  ##
  # Generates floating point numbers
  # These start small (around 0)
  # and become more extreme (large positive and large negative numbers)
  # TODO testing for NaN, Infinity?
  def float
    integer.bind do |a|
      integer.bind do |b|
        integer.bind do |c|
          Generator.wrap(fraction(a, b, c))
        end
      end
    end
  end

  ##
  # Generates a single-character string
  # from the readable ASCII character set.
  #
  # >> r = Random.new(42); 10.times.map{choose(32..128).map(&:chr).call(10, r) }
  # => ["S", "|", ".", "g", "\\", "4", "r", "v", "j", "j"]
  def readable_ascii_char
    choose(32..128).map(&:chr)
  end

  ##
  # Picks one of the given `choices` at random uniformly every time.
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
  # >> r = Random.new(42); 10.times.map { Generators.frequency(5 => Generators.integer, 1 => Generators.char).call(10, r) }
  # => [4, -3, 10, 8, 0, -7, 10, 1, "E", 10]
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
