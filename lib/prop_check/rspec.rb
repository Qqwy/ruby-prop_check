module PropCheck::RSpec
  ##
  # Integration with RSpec
  class Property < PropCheck::Property
    def check_evaluator_class
      PropCheck::RSpec::Property::CheckEvaluator
    end
  end

  class Property::CheckEvaluator
    def it(str, *args, **kwargs, &block)
      evaluator = PropCheck::Property::CheckEvaluator.new(@bindings, &block)
      @caller.it(str + "\n\twith PropCheck bindings #{@bindings.ai}", *args, **kwargs) do
        begin
          evaluator.call()
        rescue Exception => e
          @exception_handler.call(e)
        end
      end
    end
  end

  # # To make it available within examples
  # def self.extend_object(obj)
  #   obj.define_method(:forall) do |*args, **kwargs, &block|
  #     if block_given?
  #       PropCheck::RSpec::Property.forall(*args, **kwargs) do
  #         instance_exec(self, &block)
  #       end
  #     else
  #       PropCheck::Property.forall(*args, **kwargs)
  #     end
  #   end
  # end
  # end
end
