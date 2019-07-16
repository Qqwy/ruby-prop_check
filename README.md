# PropCheck

PropCheck allows you to do Property Testing in Ruby.

[![Gem](https://img.shields.io/gem/v/prop_check.svg)](https://rubygems.org/gems/prop_check)
[![Build Status](https://travis-ci.org/Qqwy/ruby-prop_check.svg?branch=master)](https://travis-ci.org/Qqwy/ruby-prop_check)
[![Maintainability](https://api.codeclimate.com/v1/badges/71897f5e6193a5124a53/maintainability)](https://codeclimate.com/github/Qqwy/ruby-prop_check/maintainability)
[![RubyDoc](https://img.shields.io/badge/%F0%9F%93%9ARubyDoc-documentation-informational.svg)](https://www.rubydoc.info/github/Qqwy/ruby-prop_check/master/PropCheck)

It features:

- Generators for common datatypes.
- An easy DSL to define your own generators (by combining existing ones, or completely custom).
- Shrinking to a minimal counter-example on failure.


## TODOs before release

Before releasing this gem on Rubygems, the following things need to be finished:

- [x]  Finalize the testing DSL.
- [x] Testing the library itself (against known 'true' axiomatically correct Ruby code.)
- [x] Customization of common settings
 - [x] Filtering generators. 
  - [x] Customize the max. of samples to run.
  - [x] Stop after a ludicrous amount of generator runs, to prevent malfunctioning (infinitely looping) generators from blowing up someone's computer.
 - [x] Look into customization of settings from e.g. command line arguments.
- [x] Good, unicode-compliant, string generators.
- [x] Filtering generator outputs.

# Nice-to-haves
 
- [ ] Basic integration with RSpec. See also https://groups.google.com/forum/#!msg/rspec/U-LmL0OnO-Y/iW_Jcd6JBAAJ for progress on this.
 - [ ] `aggregate` , `resize` and similar generator-modifying calls (c.f. PropEr's variants of these) which will help with introspection/metrics.
 - [ ] Integration with other Ruby test frameworks.
 - Stateful property testing. If implemented at some point, will probably happen in a separate add-on library.


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

For instance, when a failure happens with the input `x = 100`,
PropCheck will see if the failure still happens with `x = 50`.
If it does , it will try `x = 25`. If not, it will try `x = 75`, and so on.

This means if something only goes wrong for `x = 2`, the program will try:
- `x = 100`(fails),`
- x = 50`(fails), 
- `x = 25`(fails), 
- `x = 12`(fails), 
- `x = 6`(fails), 
- `x = 3`(fails), 
- `x = 1` (succeeds), `x = 2` (fails).

and thus the simplified case of `x = 2` is shown in the output.

The documentation of the provided generators explain how they shrink.
A short summary:
- Integers shrink to numbers closer to zero.
- Negative integers also attempt their positive alternative.
- Floats shrink similarly to integers.
- Arrays and hashes shrink to fewer elements, as well as shrinking their elements.
- Strings shrink to shorter strings, as well as characters earlier in their alphabet.


### Writing Custom Generators

PropCheck comes bundled with a bunch of common generators, for:
- integers
- floats
- strings
- symbols
- arrays
- hashes
etc.

However, you can easily adapt them to generate your own datatypes:

#### Generator#wrap

Always returns the given value. No shrinking.

#### Generator#map

Allows you to take the result of one generator and transform it into something else.
    
    >> Generators.choose(32..128).map(&:chr).call(10, Random.new(42))
    => "S"

#### Generator#bind

Allows you to create one or another generator conditionally on the output of another generator.

    >> Generators.integer.bind { |a| Generators.integer.bind { |b| Generator.wrap([a , b]) } }.call(100, Random.new(42))
    => [2, 79]


#### Generators.one_of

Useful if you want to be able to generate a value to be one of multiple possibilities:

    
    >> Generators.one_of(Generators.constant(true), Generators.constant(false)).sample(5, size: 10, rng: Random.new(42))
    => [true, false, true, true, true]

(note that for this example, you can also use `Generators.boolean`. The example happens to show how it is implemented under the hood.)

#### Generators.frequency

If `one_of` does not give you enough flexibility because you want some results to be more common than others,
you can use `Generators.frequency` which takes a hash of (integer_frequency => generator) keypairs.

    >> Generators.frequency(5 => Generators.integer, 1 => Generators.printable_ascii_char).sample(size: 10, rng: Random.new(42))
    => [4, -3, 10, 8, 0, -7, 10, 1, "E", 10]

#### Others

There are even more functions in the `Generator` class and the `Generators` module that you might want to use,
although above are the most generally useful ones.

[PropCheck::Generator documentation](https://www.rubydoc.info/github/Qqwy/ruby-prop_check/master/PropCheck/Generator)
[PropCheck::Generators documentation](https://www.rubydoc.info/github/Qqwy/ruby-prop_check/master/PropCheck/Generators)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Qqwy/ruby-prop_check . This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the PropCheck project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/prop_check/blob/master/CODE_OF_CONDUCT.md).

## Attribution and Thanks

I want to thank the original creators of QuickCheck (Koen Claessen, John Hughes) as well as the authors of many great property testing libraries that I was/am able to use as inspiration.
I also want to greatly thank Thomasz Kowal who made me excited about property based testing [with his great talk about stateful property testing](https://www.youtube.com/watch?v=q0wZzFUYCuM), 
as well as Fred Herbert for his great book [Property-Based Testing with PropEr, Erlang and Elixir](https://propertesting.com/) which is really worth the read (regardless of what language you are using).
