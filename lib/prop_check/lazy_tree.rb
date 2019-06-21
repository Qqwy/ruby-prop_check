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
  #   >> LazyTree.new(1, [LazyTree.new(2, [LazyTree.new(3)]), LazyTree.new(4)]).map(&:next)
  #   => LazyTree.new(2, [LazyTree.new(3, [LazyTree.new(4)]), LazyTree.new(5)]).map(&:next)
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
  #   >> LazyTree.new(1, [LazyTree.new(2, [LazyTree.new(3)]), LazyTree.new(4)]).each.force
  #   => [1, 2, 3, 4]
  def each#(&block)
    res = [[root], children.flat_map(&:each)].lazy.flat_map(&:lazy)
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
  #   >> LazyTree.new(1, [LazyTree.new(2, [LazyTree.new(3)]), LazyTree.new(4)]).to_a
  #   => [1, 2, 3, 4]
  def to_a
    each.force
  end
end
