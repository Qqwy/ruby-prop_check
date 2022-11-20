# PropCheck

PropCheck allows you to do Property Testing in Ruby.

[![Gem](https://img.shields.io/gem/v/prop_check.svg)](https://rubygems.org/gems/prop_check)
[![Ruby RSpec tests build status](https://github.com/Qqwy/ruby-prop_check/actions/workflows/run_tests.yaml/badge.svg)](https://github.com/Qqwy/ruby-prop_check/actions/workflows/run_tests.yaml)
[![Maintainability](https://api.codeclimate.com/v1/badges/71897f5e6193a5124a53/maintainability)](https://codeclimate.com/github/Qqwy/ruby-prop_check/maintainability)
[![RubyDoc](https://img.shields.io/badge/%F0%9F%93%9ARubyDoc-documentation-informational.svg)](https://www.rubydoc.info/github/Qqwy/ruby-prop_check/master/)

It features:

- Generators for most common Ruby datatypes.
- An easy DSL to define your own generators (by combining existing ones, as well as completely custom ones).
- Shrinking to a minimal counter-example on failure.
- Hooks to perform extra set-up/cleanup logic before/after every example case.

## What is PropCheck?

PropCheck is a Ruby library to create unit tests which are simpler to write and more powerful when run, finding edge-cases in your code you wouldn't have thought to look for.

It works by letting you write tests that assert that something should be true for _every_ case, rather than just the ones you happen to think of.


A normal unit test looks something like the following:

1. Set up some data.
2. Perform some operations on the data.
3. Assert something about the result

PropCheck lets you write tests which instead look like this:

1. For all data matching some specification.
2. Perform some operations on the data.
3. Assert something about the result.

This is often called property-based testing. It was popularised by the Haskell library [QuickCheck](https://hackage.haskell.org/package/QuickCheck). 
PropCheck takes further inspiration from Erlang's [PropEr](https://hex.pm/packages/proper), Elixir's [StreamData](https://hex.pm/packages/stream_data) and Python's [Hypothesis](https://hypothesis.works/).

It works by generating arbitrary data matching your specification and checking that your assertions still hold in that case. If it finds an example where they do not, it takes that example and shrinks it down, simplifying it to find the smallest example that still causes the problem.

Writing these kinds of tests usually consists of deciding on guarantees that your code should have -- properties that should always hold true, regardless of wat the world throws at you. Some examples are:

- Your code should not throw an exception, or only a particular type of exception.
- If you remove an object, you can no longer see it
- If you serialize and then deserializea value, you get the same value back.


## Implemented and still missing features

Before releasing v1.0, we want to finish the following:

- [x] Finalize the testing DSL.
- [x] Testing the library itself (against known 'true' axiomatically correct Ruby code.)
- [x] Customization of common settings
 - [x] Filtering generators. 
  - [x] Customize the max. of samples to run.
  - [x] Stop after a ludicrous amount of generator runs, to prevent malfunctioning (infinitely looping) generators from blowing up someone's computer.
- [x] Look into customization of settings from e.g. command line arguments.
- [x] Good, unicode-compliant, string generators.
- [x] Filtering generator outputs.
- [x] Before/after/around hooks to add setup/teardown logic to be called before/after/around each time a check is run with new data.
- [x] Possibility to resize generators.
- [x] `#instance` generator to allow the easy creation of generators for custom datatypes.
- [x] Builtin generation of `Set`s
- [x] Builtin generation of `Date`s, `Time`s and `DateTime`s.
- [x] Configuration option to resize all generators given to a particular Property instance.
- [ ] A simple way to create recursive generators
- [ ] A usage guide.

## Nice-to-haves
 
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
It takes any number of generators as arguments (or keyword arguments), as well as a block to run.
The value(s) generated from the generator(s) passed to the `forall` will be given to the block as arguments.

Raise an exception from the block if there is a problem. If there is no problem, just return normally.

```ruby
G = PropCheck::Generators
# testing that Enumerable#sort sorts in ascending order
PropCheck.forall(G.array(G.integer)) do |numbers|
  sorted_numbers = numbers.sort
  
  # Check that no number is smaller than the previous number
  sorted_numbers.each_cons(2) do |former, latter| 
    raise "Elements are not sorted! #{latter} is < #{former}" if latter < former
  end
end
```


Here is another example, using it inside a test case.
Here we check if `naive_average` indeed always returns an integer for all arrays of numbers we can pass it:

```ruby
# Somewhere you have this function definition:
def naive_average(array)
  array.sum / array.length
end
```
```ruby
# And then in a test case:
G = PropCheck::Generators
PropCheck.forall(numbers: G.array(G.integer)) do |numbers:|
  result = naive_average(numbers)
  unless result.is_a?(Integer) do
    raise "Expected the average to be an integer!"
  end
end

# Or if you e.g. are using RSpec:
describe "#naive_average" do
  include PropCheck
  G = PropCheck::Generators

  it "returns an integer for any input" do
    forall(numbers: G.array(G.integer)) do |numbers:|
      result = naive_average(numbers)      
      expect(result).to be_a(Integer)
    end
  end
end
```

When running this particular example PropCheck very quickly finds out that we have made a programming mistake:

```ruby
ZeroDivisionError: 
(after 6 successful property test runs)
Failed on: 
`{
    :numbers => []
}`

Exception message:
---
divided by 0
---

(shrinking impossible)
---
```

Clearly we forgot to handle the case of an empty array being passed to the function.
This is a good example of the kind of conceptual bugs that PropCheck (and property-based testing in general)
are able to check for.


#### Shrinking

When a failure is found, PropCheck will re-run the block given to `forall` to test
'smaller' inputs, in an attempt to give you a minimal counter-example,
from which the problem can be easily understood.

For instance, when a failure happens with the input `x = 100`,
PropCheck will see if the failure still happens with `x = 50`.
If it does , it will try `x = 25`. If not, it will try `x = 75`, and so on.

This means if something only goes wrong for `x = 2`, the program will try:
- `x = 100`(fails),
- `x = 50`(fails), 
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

### Builtin Generators

PropCheck comes with [many builtin generators in the PropCheck::Generators](https://www.rubydoc.info/github/Qqwy/ruby-prop_check/master/PropCheck/Generators) module.

It contains generators for:
- (any, positive, negative, etc.) integers, 
- (any, only real-valued) floats, 
- (any, printable only, alphanumeric only, etc) strings and symbols
- fixed-size arrays and hashes 
- as well as varying-size arrays, hashes and sets.
- dates, times, datetimes.
- and many more!

It is common and recommended to set up a module alias by using `G = PropCheck::Generators` in e.g. your testing-suite files to be able to refer to all of them.
_(Earlier versions of the library recommended including the module instead. But this will make it very simple to accidentally shadow a generator with a local variable named `float` or `array` and similar.)_

### Writing Custom Generators

As described in the previous section, PropCheck already comes bundled with a bunch of common generators.

However, you can easily adapt them to generate your own datatypes:

#### Generators#constant / Generator#wrap

Always returns the given value. No shrinking.

#### Generator#map

Allows you to take the result of one generator and transform it into something else.
    
    >> G.choose(32..128).map(&:chr).sample(1, size: 10, Random.new(42))
    => ["S"]

#### Generator#bind

Allows you to create one or another generator conditionally on the output of another generator.

    >> G.integer.bind { |a| G.integer.bind { |b| G.constant([a , b]) } }.sample(1, size: 100, rng: Random.new(42)
    => [[2, 79]]

This is an advanced feature. Often, you can use a combination of `Generators.tuple` and `Generator#map` instead:

    >> G.tuple(integer, integer).sample(1, size: 100, rng: Random.new(42)
    => [[2, 79]]

#### Generators.one_of

Useful if you want to be able to generate a value to be one of multiple possibilities:

    
    >> G.one_of(G.constant(true), G.constant(false)).sample(5, size: 10, rng: Random.new(42))
    => [true, false, true, true, true]

(Note that for this example, you can also use `G.boolean`. The example happens to show how it is implemented under the hood.)

#### Generators.frequency

If `one_of` does not give you enough flexibility because you want some results to be more common than others,
you can use `Generators.frequency` which takes a hash of (integer_frequency => generator) keypairs.

    >> G.frequency(5 => G.integer, 1 => G.printable_ascii_char).sample(size: 10, rng: Random.new(42))
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

The implementation and API of PropCheck takes a lot of inspiration from the following pre-existing libraries:

- Haskell's [QuickCheck](https://hackage.haskell.org/package/QuickCheck) and [Hedgehog](https://hackage.haskell.org/package/hedgehog);
- Erlang's [PropEr](https://hex.pm/packages/proper);
- Elixir's [StreamData](https://hex.pm/packages/stream_data);
- Python's [Hypothesis](https://hypothesis.works/).
