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


LazyTree = Struct.new(:root, :children) do
  # def full_tree
  #   # [[val], shrinktree].lazy.flat_map(&:lazy)
  # end

  # Maps `block` eagerly over `root` and lazily over `children`.
  def map(&block)
    LazyTree.new(block.call(self.root), self.children.lazy.map(&block))
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

  # Turns a LazyTree in a long lazy enumerable.
  # Be aware that this lazy enumerable is potentially infinite,
  # possibly uncountably so.
  def each(&block)
    res = [[self.root], self.children.lazy.flat_map(&:each)].lazy.flat_map(&:lazy)
    res = res.map(&block) if block_given?
    res
  end

  # Be aware that calling this might make Ruby attempt to evaluate an infinite collection.
  # It is mostly useful for debugging.
  def to_a
    each.force
  end
end

# class Generator
#   def initialize(&block)
#     @block = block
#   end

#   def generate(size, rng)
#     @block.call(size, rng)
#   end

#   def self.wrap(val)
#     Generator.new { |size, rng| LazyTree.new(val, [].lazy) }
#   end

#   def bind(&generator_proc)
#     Generator.new do |size, rng|
#       outer_result = self.generate(size, rng)
#       inner_generator = generator_proc.call(outer_result.val)

#       complex_shrinktree = outer_result.shrinktree.map do |result|
#         inner_generator = generator_proc.call(result.val)
#       end

#       combined_shrinktree = [inner_result.shrinktree, complex_shrinktree].lazy.flat_map(&:lazy)

#       LazyTree.new(inner_result.val, combined_shrinktree)
#     end
#   end

#   def map(&proc)
#     bind { |val| wrap(proc.call(val)) }
#   end
# end


# def constant(val)
#   Generator.wrap(val)
# end

# private def integer_shrink(val)
#   return [] if val.zero?

#   res = []
#   res << -val if val.abs > val

#   halvings = Helper.scanl(val) { |x| (x / 2.0).truncate }
#                .take_while { |x| !x.zero? }
#                .map { |x| val - x }

#   [res, halvings].lazy.flat_map(&:lazy)
# end


# def choose(range)
#   Generator.new do |_size, rng|
#     val = rng.rand(range)
#     LazyTree.new(val, integer_shrink(val))
#   end
# end

# def integer
#   Generator.new do |size, rng|
#     val = rng.rand(-size..size)
#     LazyTree.new(val, integer_shrink(val))
#   end
# end

# def nonnegative_integer
#   integer.map { |x| x.abs }
# end

# private def fraction(a, b, c)
#   a.to_f + b.to_f / ((c.to_f.abs) + 1.0)
# end

# def float
#   integer.bind do |a|
#     integer.bind do |b|
#       integer.bind do |c|
#         Generator.wrap(fraction(a, b, c))
#       end
#     end
#   end
# end
