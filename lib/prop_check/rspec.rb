module PropCheck::RSpec
  ##
  # Integration with RSpec
  extend self

  ##
  # Runs a property.
  # To be used _outside_ of one or multiple test cases.
  # PropCheck will create `n_runs` test cases for you,
  # and then try to run them all.
  #
  # See the README for more details.
  def forall(*args, **kwargs, &block)
    PropCheck::RSpec::Property.forall(*args, **kwargs, &block)
  end


  # Internals
  class Property < PropCheck::Property
    class CheckEvaluator < PropCheck::Property::CheckEvaluator

      def it(*args, **kwargs, &block)
        str, args =
             if args.empty?
               ["", []]
             else
               [args[0], args[1..args.size]]
             end

        # Required because the 'rescue' block will be evaluated in a different context where instance variables no longer exist.
        exception_handler = @exception_handler
        shrinking = @shrinking

        evaluator = self.class.new(@generator_result, exception_handler, &block)
        @caller.it(str + "\t(PropCheck bindings #{@bindings.ai(multiline: false)})", *args, **kwargs) do
          begin
            evaluator.call()
          rescue Exception => e
            exception_handler.call(e)
          end
        end
      end
      alias_method :property, :it

      def describe(*args, **kwargs, &block)
        exception_handler = @exception_handler
        evaluator = self.class.new(@generator_result, exception_handler, &block)
        @caller.describe(*args, **kwargs) do
          evaluator.call()
        end
      end
    end

    def self.check_evaluator_class
      CheckEvaluator
    end
  end
end
