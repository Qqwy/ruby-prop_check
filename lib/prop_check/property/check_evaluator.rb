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
      # include RSpec::Matchers if Object.const_defined?('RSpec')

      def initialize(bindings, &block)
        # @caller = block.binding.receiver
        @block = block
        # define_named_instance_methods(bindings)
        @bindings = bindings
      end

      def call
        # self.instance_exec(&@block)
        @block.call(@bindings)
      end

      # private def define_named_instance_methods(results)
      #   results.each do |name, result|
      #     define_singleton_method(name) { result }
      #   end
      # end

      ##
      # Dispatches to caller whenever something is not part of `bindings`.
      # (No need to invoke this method manually)
      # def method_missing(method, *args, &block)
      #   @caller.__send__(method, *args, &block) || super
      # end

      ##
      # Checks respond_to of caller whenever something is not part of `bindings`.
      # (No need to invoke this method manually)
      # def respond_to_missing?(*args)
      #   @caller.respond_to?(*args) || super
      # end
    end
  end
end
