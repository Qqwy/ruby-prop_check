setup_and_test: setup test

setup:
  bin/setup

test:
  bundle exec rspec

console:
  bin/console

install:
  bundle exec rake install

release:
  bundle exec rake release
