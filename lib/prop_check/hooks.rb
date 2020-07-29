class PropCheck::Hooks
  attr_accessor :before, :after
  def initialize()
    @before = proc {}
    @after = proc {}
  end

  def add_before(&hook)
    old_before = before
    @before = proc {
      old_before.call
      hook.call
    }
  end

  def add_after(&hook)
    @after = proc {
      hook.call
      old_after.call
    }
  end

  def add_around(&hook)
    around_before, around_after = split_around(hook)
    add_before(around_before)
    add_after(around_after)
  end

  def enumerate_wrapped(inner_enum)
    enum = inner_enum.to_enum

    loop do
      begin
        @hooks.before.call
        yield enum.next
      ensure
        @hooks.after.call
      end
    end
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
end
