##
# Helper functions that have no other place to live
module Helper
  ##
  # Creates a (potentially lazy) Enumerator
  # starting with `elem`
  # with each consecutive element obtained
  # by calling `operation` on the previous element.
  #
  #   >> Helper.scanl(0, &:next).take(10).force
  #   => [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
  #   >> Helper.scanl([0, 1]) { |curr, next_elem| [next_elem, curr + next_elem] }.map(&:first).take(10).force
  #   => [0, 1, 1, 2, 3, 5, 8, 13, 21, 34]
  def self.scanl(elem, &operation)
    Enumerator.new do |yielder|
      acc = elem
      loop do
        # p acc
        yielder << acc
        acc = operation.call(acc)
      end
    end.lazy
  end
end
