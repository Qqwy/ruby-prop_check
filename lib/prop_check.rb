require "prop_check/version"
require 'prop_check/property'
require 'prop_check/generator'
require 'prop_check/generators'
require 'prop_check/helper'
##
# Main module of the PropCheck library.
#
# You probably want to look at the documentation of
# PropCheck::Generator and PropCheck::Generators
# to find out more about how to use generators.
#
# Common usage is to call `extend PropCheck` in your (testing) modules.
#
# This will:
# 1. Add the local method `forall` which  will call `PropCheck.forall`
# 2. `include PropCheck::Generators`.
#
module PropCheck
  module Errors
    class Error < StandardError; end
    class UserError < Error; end
    class GeneratorExhaustedError < UserError; end
    class MaxShrinkStepsExceededError < UserError; end
  end

  extend self

  ##
  # Runs a property.
  #
  # See the README for more details.
  def forall(*args, **kwargs, &block)
    PropCheck::Property.forall(*args, **kwargs, &block)
  end
end
