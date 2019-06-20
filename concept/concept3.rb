module Helper
  def self.scanl(elem, &op)
    Enumerator.new do |yielder|
      acc = elem
      loop do
        p acc
        yielder << acc
        acc = op.call(acc)
      end
    end.lazy
  end
end


LazyTree = Struct.new(:root, :children) do
  def children
    (self[:children] || [].lazy)
  end

  # Maps `block` eagerly over `root` and lazily over `children`.
  def map(&block)
    LazyTree.new(block.call(self.root), self.children.map { |child_tree| child_tree.map(&block) })
  end

  # Turns a tree of trees
  # in a single flattened tree, with subtrees that are closer to the root
  # and the left subtree earlier in the list of children.
  def flatten
    root_tree = self.root
    root_root = root_tree.root
    root_children = root_tree.children
    child_trees = self.children

    LazyTree.new(root_root, [root_children, child_trees.map(&:flatten)].lazy.flat_map(&:lazy))
  end

  # Combines a collection of trees together into one tree of a collection.
  # TODO permutate children
  def self.zip(collection_of_trees)
    roots = collection_of_trees.map(&:root)
    children = collection_of_trees.map(&:children).permutation
    puts "CHILDREN:"
    p children
    LazyTree.new(roots, children)
  end

  # Turns a LazyTree in a long lazy enumerable.
  # Be aware that this lazy enumerable is potentially infinite,
  # possibly uncountably so.
  def each#(&block)
    res = [[self.root], self.children.flat_map(&:each)].lazy.flat_map(&:lazy)
    # res = res.map(&block) if block_given?
    res
  end

  # Be aware that calling this might make Ruby attempt to evaluate an infinite collection.
  # It is mostly useful for debugging.
  def to_a
    each.force
  end
end

class Generator
  def initialize(&block)
    @block = block
  end

  def generate(size, rng)
    @block.call(size, rng)
  end

  def self.wrap(val)
    Generator.new { |size, rng| LazyTree.new(val, []) }
  end

  def bind(&generator_proc)
    Generator.new do |size, rng|
      outer_result = self.generate(size, rng)
      res = outer_result.map do |outer_val|
        inner_generator = generator_proc.call(outer_val)
        inner_generator.generate(size, rng)
      end.flatten
    end
  end

  def map(&proc)
    # bind { |val| Generator.wrap(proc.call(val)) }
    Generator.new do |size, rng|
      result = self.generate(size, rng)
      result.map(&proc)
    end
  end
end


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

  def tuple(*generators)
    # generators.map(&:bind).reduce do ||
    # end
    generators.reduce(Generator.wrap([])) do |acc, generator|
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

  binding_generator = tuple(*bindings.map { |key, generator| generator.map { |val| [key, val] } }).map { |val| val.to_h }

  rng = Random::DEFAULT
  n_successful = 0
  generator_results = nil
  begin
    (1..1000).each do |size|
      # generator_results = bindings.map { |name, generator| [name, generator.generate(size, rng)] }.to_h
      generator_results = binding_generator.generate(size, rng)
      PropertyCheckEvaluator.new(generator_results.root, &block).call()
      n_successful += 1
    end
  rescue   Exception => problem
    puts "FAILURE #{n_successful} successful tests. Failed on:\n#{print_roots(generator_results.root)}"
    puts "Shrinking..."
    shrink(generator_results, &block)
  end
end

def print_roots(lazy_tree_hash)
  lazy_tree_hash.map do |name, val|
    "#{name} = #{val.inspect}"
  end.join(", ")
end

def hash_of_trees2tree_of_hashes(hash_of_trees)
  p hash_of_trees.each.force
  # p hash_of_trees
  # res = hash_of_trees.map do |key, tree|
  #   tree.map { |val| [key, val] }
  # end

  # p res

  # zres = LazyTree.zip(res)
  # p zres

  # p zres.to_a

  # hres = zres.each { |coll| puts "COLL:"; p coll.lazy.force; coll.to_h }
  # p hres

  # hres
end

def shrink(bindings, &block)
  # res = hash_of_trees2tree_of_hashes(bindings)
  # p res.lazy.force



  # p res.children.first
end

include Generators

forall x: integer, y: nonnegative_integer, z: float do
  puts x
  puts y
  puts z

  if y == 10
    raise "Boom!"
  end

  x > y == z
end
