module PropCheck
  ##
  # Integration with RSpec
  module RSpec
    # To make it available within examples
    def self.extend_object(obj)
      obj.define_method(:forall) do |*args, **kwargs, &block|
        PropCheck::Property.forall(*args, **kwargs) do
          instance_exec(self, &block)
        end
      end
    end
  end
end
