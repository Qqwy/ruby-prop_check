module PropCheck
  ##
  # Integration with RSpec
  module RSpec
    require 'rspec/core'
    extend ::RSpec::Core::Hooks

    def prop_check_hooks
      @@prop_check_hooks
    end


    # @@prop_check_hooks = 10

    def before(*args, &block)
      if args&.first == :each_prop_check_iteration
        @@prop_check_hooks.before.append block
      else
        super(*args, &block)
      end
    end

    def after(*args, &block)
      if args&.first == :each_prop_check_iteration
        @@prop_check_hooks.after.prepend block
      else
        super(*args, &block)
      end
    end

    def around(*args, &block)
      if args&.first == :each_prop_check_iteration
        old_hook = prop_check_hooks.around.dup
        @@prop_check_hooks.around = proc { |thing| block.call { old_hook.call(&thing) } }
        # self.prop_check_hooks.around.append block
      else
        super(*args, &block)
      end
    end

    # def prop_check_hooks
    #   @prop_check_hooks ||= self&.superclass&.prop_check_hooks || {before: [], after: [], around: proc { |inner| inner.call }}
    #   p @prop_check_hooks
    #   @prop_check_hooks
    # end

    # To make it available within examples
    def self.extend_object(obj)
      # @prop_check_hooks = self&.superclass&.prop_check_hooks || {before: [], after: [], around: proc { |inner| inner.call }}

      obj.define_method(:forall) do |*args, **kwargs, &block|
        # TODO before/after/around handling
        hooks = @prop_check_hooks
        # combined_around_hook = hooks.around.reduce( proc { |inner| inner.call }) do |acc, elem|
        #   acc.call(&elem)
        # end
        PropCheck::Property.forall(*args, **kwargs) do
          # hooks.around.call do
            # hooks.before.each(&:call)

            instance_exec(self, &block)

            # hooks.after.each(&:call)
          # end
        end
      end

      # obj.define_method(:prop_check_hooks) do
      #   # @prop_check_hooks
      #   metadata.prop_check_hooks ||= {before: [], after: [], around: proc { |inner| inner.call }}
      #   p metadata
      #   metadata.prop_check_hooks
      # end
    end
  end
end
