##
# A refinement for enumerators
# to allow lazy appending of two (potentially lazy) enumerators:
#   >> [1,2,3].lazy_append([4,5.6]).to_a
#   => [1,2,3,4,5,6]
module LazyAppend
  refine Enumerable do
    def lazy_append(other_enumerator)
      [self, other_enumerator].lazy.flat_map(&:itself)
    end
  end
end

module PropCheck
  ##
  # A Rose tree with the root being eager,
  # and the children computed lazily, on demand.
  class LazyTree
    using LazyAppend

    attr_accessor :root, :children
    def initialize(root, children = [].lazy)
      @root = root
      @children = children
    end

    ##
    # Maps `block` eagerly over `root` and lazily over `children`, returning a new LazyTree as result.
    #
    #   >> LazyTree.new(1, [LazyTree.new(2, [LazyTree.new(3)]), LazyTree.new(4)]).map(&:next)
    #   => LazyTree.new(2, [LazyTree.new(3, [LazyTree.new(4)]), LazyTree.new(5)]).map(&:next)
    def map(&block)
      new_root = block.call(root)
      new_children = children.map { |child_tree| child_tree.map(&block) }
      LazyTree.new(new_root, new_children)
    end

    ##
    # Turns a tree of trees
    # in a single flattened tree, with subtrees that are closer to the root
    # and the left subtree earlier in the list of children.
    # TODO: Check for correctness
    def flatten
      root_tree = root
      root_root = root_tree.root

      root_children = root_tree.children
      flattened_children = children.map(&:flatten)

      combined_children = root_children.lazy_append(flattened_children)

      LazyTree.new(root_root, combined_children)
    end

    def self.wrap(val)
      LazyTree.new(val)
    end

    def bind(&fun)
      child_tree = fun.call(root)
      mapped_children = children.map { |child| child.bind(&fun) }

      combined_children = child_tree.children.lazy_append(mapped_children)

      LazyTree.new(child_tree.root, combined_children)
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
    def each(&block)
      base = [root]
      recursive = children.map(&:each)
      res = base.lazy_append(recursive)

      return res.each(&block) if block_given?

      res

      # res = [[root], children.flat_map(&:each)].lazy.flat_map(&:lazy)
      # res = res.map(&block) if block_given?
      # res
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

    # TODO: fix implementation
    # def self.zip(trees)
    #   p self
    #   new_root = trees.map(&:root)
    #   p new_root
    #   new_children = trees.permutations.flat_map(&:children)
    #   p new_children
    #   LazyTree.new(new_root, new_children)
    # end
  end
end
