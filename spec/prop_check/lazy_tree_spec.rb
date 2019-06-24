require 'doctest/rspec'

LazyTree = PropCheck::LazyTree

RSpec.describe PropCheck::LazyTree do

  using LazyAppend
    doctest PropCheck::LazyTree
end
