module PropCheck
  ##
  # Integration with RSpec
  module RSpec
    # To make it available within examples
    def self.extend_object(obj)
      obj.define_method(:forall) do |*args, **kwargs, &block|
        if block_given?
          PropCheck::Property.forall(*args, **kwargs) do
            instance_exec(self, &block)
          end
        else
          PropCheck::Property.forall(*args, **kwargs)
        end
      end
    end
  end
end
