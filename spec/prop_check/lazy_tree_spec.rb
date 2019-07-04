require 'doctest/rspec'

LazyTree = PropCheck::LazyTree

RSpec.describe PropCheck::LazyTree do

  using Helper::LazyAppend
    doctest PropCheck::LazyTree
end
