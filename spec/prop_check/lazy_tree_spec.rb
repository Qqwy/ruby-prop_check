require 'doctest/rspec'

LazyTree = PropCheck::LazyTree

RSpec.describe PropCheck::LazyTree do

  using PropCheck::Helper::LazyAppend
    doctest PropCheck::LazyTree
end
