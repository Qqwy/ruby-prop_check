require "prop_check/version"

module PropCheck
  class Error < StandardError; end
  include PropCheck::Property
end
