# frozen_string_literal: true

module PropCheck
  ##
  # A Rose tree with the root being eager,
  # and the children computed lazily, on demand.
  class LazyTree
    require 'prop_check/helper'

    include Enumerable

    attr_accessor :root
    def initialize(root, children = [].lazy)
      @root = root
      @children = children
    end

    def children
      @children.reject { |child| child.root == :"_PropCheck.filter_me" }
    end

    ##
    # Maps `block` eagerly over `root` and lazily over `children`, returning a new LazyTree as result.
    #
    #   >> LazyTree.new(1, [LazyTree.new(2, [LazyTree.new(3)]), LazyTree.new(4)]).map(&:next).to_a
    #   => LazyTree.new(2, [LazyTree.new(3, [LazyTree.new(4)]), LazyTree.new(5)]).to_a
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
    # def flatten
    #   root_tree = root
    #   root_root = root_tree.root

    #   root_children = root_tree.children
    #   flattened_children = children.map(&:flatten)

    #   combined_children = PropCheck::Helper.lazy_append(root_children, flattened_children)

    #   LazyTree.new(root_root, combined_children)
    # end

    def self.wrap(val)
      LazyTree.new(val)
    end

    def bind(&fun)
      inner_tree = fun.call(root)
      inner_root = inner_tree.root
      inner_children = inner_tree.children
      mapped_children = children.map { |child| child.bind(&fun) }

      combined_children = PropCheck::Helper.lazy_append(inner_children, mapped_children)

      LazyTree.new(inner_root, combined_children)
    end

    ##
    # Turns a LazyTree in a long lazy enumerable, with the root first followed by its children
    # (and the first children's result before later children; i.e. a depth-first traversal.)
    #
    # Be aware that this lazy enumerable is potentially infinite,
    # possibly uncountably so.
    #
    #   >> LazyTree.new(1, [LazyTree.new(2, [LazyTree.new(3)]), LazyTree.new(4)]).each.force
    #   => [1, 4, 2, 3]
    def each(&block)
      self.to_enum(:each) unless block_given?

      squish([])
      .each(&block)
    end

    protected def squish(arr)
      new_children = self.children.reduce(arr) { |acc, elem| elem.squish(acc) }
      PropCheck::Helper.lazy_append([self.root], new_children)
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
    #   => [1, 4, 2, 3]
    def to_a
      each
        .force
    end

    # TODO: fix implementation
    def self.zip(trees)
      # p "TREES: "
      # p trees.to_a
      # p "END TREES"
      # raise "Boom!" unless trees.to_a.is_a?(Array) && trees.to_a.first.is_a?(LazyTree)
      # p self
      new_root = trees.to_a.map(&:root)
      # p new_root
      # new_children = trees.permutations.flat_map(&:children)
      new_children = permutations(trees).map { |children| LazyTree.zip(children) }
      # p new_children
      LazyTree.new(new_root, new_children)
    end

    private_class_method def self.permutations(trees)
      # p trees
      trees.lazy.each_with_index.flat_map do |tree, index|
        tree.children.map do |child|
          child_trees = trees.to_a.clone
          child_trees[index] = child
          # p "CHILD TREES:"
          # p child_trees
          child_trees.lazy
        end
      end
    end

  end
end
