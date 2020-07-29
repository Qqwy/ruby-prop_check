##
# @api private
module PropCheck::Property::OutputFormatter
  extend self

  def pre_output(output, n_successful, generated_root, problem)
    output.puts ""
    output.puts "(after #{n_successful} successful property test runs)"
    output.puts "Failed on: "
    output.puts "`#{print_roots(generated_root)}`"
    output.puts ""
    output.puts "Exception message:\n---\n#{problem}"
    output.puts "---"
    output.puts ""

    output
  end

  def post_output(output, n_shrink_steps, shrunken_result, shrunken_exception)
    if n_shrink_steps == 0
      output.puts '(shrinking impossible)'
    else
      output.puts ''
      output.puts "Shrunken input (after #{n_shrink_steps} shrink steps):"
      output.puts "`#{print_roots(shrunken_result)}`"
      output.puts ""
      output.puts "Shrunken exception:\n---\n#{shrunken_exception}"
      output.puts "---"
      output.puts ""
    end
    output
  end

  def print_roots(lazy_tree_val)
    if lazy_tree_val.is_a?(Array) && lazy_tree_val.length == 1 && lazy_tree_val[0].is_a?(Hash)
      lazy_tree_val[0].ai
    else
      lazy_tree_val.ai
    end
  end
end
