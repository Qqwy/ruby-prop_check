module PropCheck
  module Helper
    ##
    # A refinement for enumerators
    # to allow lazy appending of two (potentially lazy) enumerators:
    #   >> [1,2,3].lazy_append([4,5.6]).to_a
    #   => [1,2,3,4,5,6]
    module LazyAppend
      refine Enumerable do
        ##   >> [1,2,3].lazy_append([4,5.6]).to_a
        ##   => [1,2,3,4,5,6]
        def lazy_append(other_enumerator)
          [self, other_enumerator].lazy.flat_map(&:lazy)
        end
      end
    end
  end
end
