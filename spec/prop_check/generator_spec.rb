require 'doctest/rspec'


RSpec.describe PropCheck::Generator do
  Generator = PropCheck::Generator
  Generators = PropCheck::Generators
  doctest PropCheck::Generator
  doctest PropCheck::Generators
end
