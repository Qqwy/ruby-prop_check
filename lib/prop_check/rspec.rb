module PropCheck
  ##
  # Integration with RSpec
  #
  # Currently very basic; it does two things:
  # 1. adds the local `forall` method to examples that calls `PropCheck.forall`
  # 2. adds `include PropCheck::Generators` statement.
  module RSpec
    # To make it available within examples
    def self.extend_object(obj)
      obj.instance_eval do
        include PropCheck::Generators
      end

      obj.define_method(:forall) do |*args, **kwargs, &block|
        PropCheck.forall(*args, **kwargs, &block)
      end
    end
  end
end
