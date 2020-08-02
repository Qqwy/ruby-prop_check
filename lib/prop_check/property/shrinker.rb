require 'prop_check/helper'
class PropCheck::Property::Shrinker
  def initialize(bindings_tree, io, hooks, config)
    @problem_child = bindings_tree
    @io = io
    @siblings = @problem_child.children.lazy
    @parent_siblings = nil
    @problem_exception = nil
    @shrink_steps = 0
    @hooks = hooks
    @config = config
  end

  def self.call(bindings_tree, io, hooks, config, &block)
    self
      .new(bindings_tree, io, hooks, config)
      .call(&block)
  end

  def call(&block)
    @io.puts 'Shrinking...' if @config.verbose

    shrink(&block)

    print_shrinking_exceeded_message if @shrink_steps >= @config.max_shrink_steps

    [@problem_child.root, @problem_exception, @shrink_steps]
  end

  private def shrink(&block)
    wrapped_enum.each do
      instruction, sibling = safe_read_sibling
      break if instruction == :break
      next if instruction == :next

      inc_shrink_step

      safe_call_block(sibling, &block)
    end
  end

  private def wrapped_enum
    @hooks.wrap_enum(0..@config.max_shrink_steps).lazy
  end

  private def inc_shrink_step
    @shrink_steps += 1
    @io.print '.' if @config.verbose
  end

  private def safe_read_sibling
    begin
      sibling = @siblings.next
      [:continue, sibling]
    rescue StopIteration
      return [:break, nil] if @parent_siblings.nil?

      @siblings = @parent_siblings.lazy
      @parent_siblings = nil
      [:next, nil]
    end
  end

  private def safe_call_block(sibling, &block)
    begin
      PropCheck::Helper.call_splatted(sibling.root, &block)
    # It is correct that we want to rescue _all_ Exceptions
    # not only 'StandardError's
    rescue Exception => e
      @problem_child = sibling
      @parent_siblings = @siblings
      @siblings = @problem_child.children.lazy
      @problem_exception = e
    end
  end

  private def print_shrinking_exceeded_message
    @io.puts "(Note: Exceeded #{@config.max_shrink_steps} shrinking steps, the maximum.)"
  end
end
