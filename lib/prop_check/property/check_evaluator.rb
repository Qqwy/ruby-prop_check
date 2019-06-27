module PropCheck
  class Property
    ##
    # A wrapper class that implements the 'Cloaker' concept
    # which allows us to refer to variables set in 'bindings',
    # while still being able to access things that are only in scope
    # in the creator of '&block'.
    #
    # This allows us to bind the variables specified in `bindings`
    # one way during checking and another way during shrinking.
    class CheckEvaluator
      include RSpec::Matchers if Object.const_defined?('RSpec')

      def initialize(bindings, &block)
        @caller = eval 'self', block.binding, __FILE__, __LINE__
        @block = block
        define_named_instance_methods(bindings)
      end

      def call
        instance_exec(&@block)
      end

      private def define_named_instance_methods(results)
        results.each do |name, result|
          define_singleton_method(name) { result }
        end
      end

      # :nocov:
      # SimpleCov seems to be having problems with `method_missing`
      # An issue has been made; see https://github.com/colszowka/simplecov/issues/728
      # Rest assured: these two methods are _definitely_ being called,
      # since they are heavily exercised in the test suite.

      ##
      # Dispatches to caller whenever something is not part of `bindings`.
      # (No need to invoke this method manually)
      def method_missing(method, *args, &block)
        super || @caller.__send__(method, *args, &block)
      end

      ##
      # Checks respond_to of caller whenever something is not part of `bindings`.
      # (No need to invoke this method manually)
      def respond_to_missing?(*args)
        super || @caller.respond_to?(*args)
      end
      # :nocov
    end
  end
end
