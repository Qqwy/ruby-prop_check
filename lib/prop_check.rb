require "prop_check/version"
require 'prop_check/property'
require 'prop_check/generator'
require 'prop_check/generators'
require 'prop_check/helper'
module PropCheck
  class Error < StandardError; end
  extend PropCheck::Property
end
