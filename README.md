# PropCheck

PropCheck allows you to do Property Testing in Ruby.

It features:

- Generators for common datatypes.
- An easy DSL to define your own generators (by combining existing ones, or completely custom).
- Shrinking to a minimal counter-example on failure.


## TODOs before release

Before releasing this gem on Rubygems, the following things need to be finished:

- Finalize the testing DSL.
- Testing the library itself (against known 'true' axiomatically correct Ruby code.)
- Basic integration with RSpec. See also https://groups.google.com/forum/#!msg/rspec/U-LmL0OnO-Y/iW_Jcd6JBAAJ for progress on this.
- Customization of common settings
 - Filtering generators. 
  - Customize the max. of samples to run.
  - Stop after a ludicrous amount of generator runs, to prevent malfunctioning (infinitely looping) generators from blowing up someone's computer.
  
# Nice-to-haves
 
 - `aggregate` , `resize` and similar generator-modifying calls (c.f. PropEr's variants of these) which will help with introspection/metrics.
 - Integration with other Ruby test frameworks.
 - Stateful property testing. (A whole other can of worms, but super cool!)


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'prop_check'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install prop_check

## Usage


### Using PropCheck for basic testing

Propcheck exposes the `forall` method.
It takes generators as keyword arguments and a block to run.
Inside the block, each of the names in the keyword-argument-list is available by its name.

_(to be precise: a method on the execution context is defined which returns the current generated value for that name)_

Raise an exception from the block if there is a problem. If there is no problem, just return normally.

```ruby
# testing that Enumerable#sort sorts in ascending order
PropCheck.forall(numbers: array(integer())) do
  sorted_numbers = numbers.sort
  
  # Check that no number is smaller than the previous number
  sorted_numbers.each_cons(2) do |former, latter| 
    raise "Elements are not sorted! #{latter} is < #{former}" if latter < former
  end
end
```

#### Shrinking

When a failure is found, PropCheck will re-run the block given to `forall` to test
'smaller' inputs, in an attempt to give you a minimal counter-example,
from which the problem can be easily understood.

TODO example code+output here.

### Writing Custom Generators

PropCheck comes bundled with a bunch of common generators, for:
- integers
- floats
- strings
- symbols
- arrays
- hashes
etc.

However, you of course have your own data-types in your project.

Adapting one of the generators for your own datatype is easy.

(TODO expand on this)


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Qqwy/ruby-prop_check . This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the PropCheck project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/prop_check/blob/master/CODE_OF_CONDUCT.md).
