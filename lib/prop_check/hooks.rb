# frozen_string_literal: true

##
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
  attr_reader :before, :after
  def initialize()
    @before = proc {}
    @after = proc {}
  end

  ##
  # Adds `hook` to the `before` proc.
  # It is called after earlier-added `before` procs.
  def add_before(&hook)
    old_before = before
    @before = proc {
      old_before.call
      hook.call
    }
  end

  ##
  # Adds `hook` to the `after` proc.
  # It is called before earlier-added `after` procs.
  def add_after(&hook)
    @after = proc {
      hook.call
      old_after.call
    }
  end

  ##
  # Adds `hook` as an around hook.
  #
  # An around hook is passed the inner implementation as a block
  # and should call it using `yield` (or `&block.call` etc) at the appropriate time.
  #
  # Internally we use continuations to 'split' `hook` into
  # a `before` and `after` callback.
  def add_around(&hook)
    around_before, around_after = split_around(hook)
    add_before(around_before)
    add_after(around_after)
  end

  private def split_around(hook)
    require 'continuation'
    after_cont = nil

    around_before = proc do |*args|
      callcc do |outer_cont|
        hook.call(*args) do |*hook_args|
          callcc do |cont|
            after_cont = cont
            # Returns the args `hook` yields with from the `around_before` proc.
            outer_cont.call(*hook_args)
          end
        end
      end
    end

    around_after = proc do |*args|
      # Injects the arguments given to the `around_after` block
      # as return values of the `yield` that `hook` has used.
      after_cont.call(*args)
    end

    [around_before, around_after]
  end

  ##
  # Wraps enumerable `inner` with a `PropCheck::Hooks` object
  # such that the before/after/around hooks are called
  # before/after/around each element that is fetched from `inner`.
  #
  # This is very helpful if you need to perform cleanup logic
  # before/after/around e.g. data is generated or fetched.
  class Enumerable
    include ::Enumerable

    def initialize(inner, hooks)
      @inner = inner
      @hooks = hooks
    end

    def each(&block)
      return to_enum(:each) unless block_given?

      enum = @inner.to_enum
      loop do
        begin
          @hooks.before.call()
          yield enum.next(&block)
        ensure
          @hooks.after.call()
        end
      end
    end
  end
end
