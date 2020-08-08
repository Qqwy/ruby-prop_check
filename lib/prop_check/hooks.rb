# frozen_string_literal: true

##
# @api private
# Contains the logic to combine potentially many before/after/around hooks
# into a single pair of procedures called `before` and `after`.
#
# _Note: This module is an implementation detail of PropCheck._
#
# These can be invoked by manually calling `#before` and `#after`.
# Important:
# - Always call first `#before` and then `#after`.
#   This is required to make sure that `around` callbacks will work properly.
# - Make sure that if you call `#before`, to also call `#after`.
#   It is thus highly recommended to call `#after` inside an `ensure`.
#   This is to make sure that `around` callbacks indeed perform their proper cleanup.
#
# Alternatively, check out `PropCheck::Hooks::Enumerable` which allows
# wrapping the elements of an enumerable with hooks.
class PropCheck::Hooks
  # attr_reader :before, :after, :around
  def initialize()
    @before = proc {}
    @after = proc {}
    @around = proc { |*args, &block| block.call(*args) }
  end

  def wrap_enum(enumerable)
    PropCheck::Hooks::Enumerable.new(enumerable, self)
  end


  ##
  # Wraps a block with all hooks that were configured this far.
  #
  # This means that whenever the block is called,
  # the before/around/after hooks are called before/around/after it.
  def wrap_block(&block)
    proc { |*args| call(*args, &block) }
  end

  ##
  # Wraps a block with all hooks that were configured this far,
  # and immediately calls it using the given `*args`.
  #
  # See also #wrap_block
  def call(*args, &block)
    begin
      @before.call()
      @around.call do
        block.call(*args)
      end
    ensure
      @after.call()
    end
  end

  ##
  # Adds `hook` to the `before` proc.
  # It is called after earlier-added `before` procs.
  def add_before(&hook)
    old_before = @before
    @before = proc {
      old_before.call
      hook.call
    }
    self
  end

  ##
  # Adds `hook` to the `after` proc.
  # It is called before earlier-added `after` procs.
  def add_after(&hook)
    old_after = @after
    @after = proc {
      hook.call
      old_after.call
    }
    self
  end

  ##
  # Adds `hook` to the `around` proc.
  # It is called _inside_ earlier-added `around` procs.
  def add_around(&hook)
    old_around = @around
    @around = proc do |&block|
      old_around.call do |*args|
        hook.call(*args, &block)
      end
    end
    self
  end

  ##
  # @api private
  # Wraps enumerable `inner` with a `PropCheck::Hooks` object
  # such that the before/after/around hooks are called
  # before/after/around each element that is fetched from `inner`.
  #
  # This is very helpful if you need to perform cleanup logic
  # before/after/around e.g. data is generated or fetched.
  #
  # Note that whatever is after a `yield` in an `around` hook
  # is not guaranteed to be called (for instance when a StopIteration is raised).
  # Thus: make sure you use `ensure` to clean up resources.
  class Enumerable
    include ::Enumerable

    def initialize(inner, hooks)
      @inner = inner
      @hooks = hooks
    end

    def each(&task)
      return to_enum(:each) unless block_given?

      enum = @inner.to_enum

      wrapped_yielder = @hooks.wrap_block do
        yield enum.next(&task)
      end

      loop(&wrapped_yielder)
    end
  end
end
