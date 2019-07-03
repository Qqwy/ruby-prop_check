RSpec.describe PropCheck do
  it "has a version number" do
    expect(PropCheck::VERSION).not_to be nil
  end

  describe PropCheck do
    describe ".forall" do
      it "returns a Property when called without a block" do
        expect(PropCheck.forall(x: PropCheck::Generators.integer)).to be_a(PropCheck::Property)
      end

      it "runs the property test when called with a block" do
        expect { |block| PropCheck.forall(x: PropCheck::Generators.integer, &block) }.to yield_control
      end

      it "will not shrink upon encountering a SystemExit" do
        expect do
          PropCheck.forall(x: PropCheck::Generators.integer) do
            raise SystemExit if x > 3
          end
        end.to raise_error do |error|
          expect(error).to be_a(SystemExit)

          # Check for no shrinking:
          expect(defined?(error.prop_check_info)).to be_nil
        end
      end

      it "will not shrink upon encountering a SignalException" do
        expect do
          PropCheck.forall(x: PropCheck::Generators.integer) do
            Process.kill('HUP',Process.pid) if x > 3
          end
        end.to raise_error do |error|
          expect(error).to be_a(SignalException)

          # Check for no shrinking:
          expect(defined?(error.prop_check_info)).to be_nil
        end
      end

      it "shrinks and returns an exception with the #prop_check_info method upon finding a failure case" do

        class MyCustomError < StandardError; end
        expected_keys = [:original_input, :original_exception_message, :shrunken_input, :shrunken_exception, :n_successful, :n_shrink_steps]
        exploding_val = nil
        shrunken_val = nil

        expect do
          PropCheck.forall(x: PropCheck::Generators.float) do
            if x > 3.1415
              exploding_val ||= x
              shrunken_val = x
              raise MyCustomError, "I do not like this number"
            end
          end
        end.to raise_error do |error|
          expect(error).to be_a(MyCustomError)
          expect(defined?(error.prop_check_info)).to eq("method")
          info = error.prop_check_info
          expect(info.keys).to contain_exactly(*expected_keys)

          expect(info[:original_exception_message]).to eq("I do not like this number")
          expect(info[:original_input]).to eq({ x: exploding_val })
          expect(info[:shrunken_input]).to eq({ x: shrunken_val })
          expect(info[:n_successful]).to be_a(Integer)
          expect(info[:n_shrink_steps]).to be_a(Integer)
        end
      end
    end

    describe "Property" do
      describe "#with_config" do
        it "updates the configuration" do
          p = PropCheck.forall(x: PropCheck::Generators.integer)
          expect(p.configuration[:verbose]).to be false
          expect(p.with_config(verbose: true).configuration[:verbose]).to be true
        end
        it "Runs the property test when called with a block" do
          expect { |block| PropCheck.forall(x: PropCheck::Generators.integer).with_config({}, &block) }.to yield_control
        end
      end

      describe "#check" do
        it "generates an error that Rspec can pick up" do
          expect do
            PropCheck.forall(x: PropCheck::Generators.nonnegative_integer) do
              expect(x).to be < 100
            end
          end.to raise_error do |error|
            expect(error).to be_a(RSpec::Expectations::ExpectationNotMetError)
            expect(error.message).to match(/\(after \d+ successful property test runs\)/m)
            expect(error.message).to match(/Exception message:/m)

            # Test basic shrinking real quick:
            expect(error.message).to match(/Shrunken input \(after \d+ shrink steps\):\n`x = 100`/m)
            expect(error.message).to match(/Shrunken exception:/m)

            expect(defined?(error.prop_check_info)).to eq("method")
            # p error.prop_check_info
          end
        end
      end

      describe "#where" do
        it "filters results" do
          PropCheck.forall(y: PropCheck::Generators.integer, x: PropCheck::Generators.positive_integer).where { x != y}.check do
            expect(x).to_not eq y
          end
        end

        it "raises an error if too much was filtered" do
          expect do
            PropCheck.forall(x: PropCheck::Generators.nonpositive_integer).where {x == 0}.check do
            end
          end.to raise_error do |error|
            expect(error).to be_a(PropCheck::GeneratorExhaustedError)
            # Check for no shrinking:
            expect(defined?(error.prop_check_info)).to be_nil
          end
        end

        it "crashes when doing bullshit in the where block" do
          expect do
            PropCheck.forall(x: PropCheck::Generators.negative_integer).where {x.unexistentmethod == 3}.check do
            end
          end.to raise_error do |error|
            expect(error).to be_a(NoMethodError)
            # Check for no shrinking:
            expect(defined?(error.prop_check_info)).to be_nil
          end
        end

      end

      describe "CheckEvaluator" do
        it "forwards through method_missing when methods on outer scope are being called" do
          expect do
            x = 10
            def call_me(input)
              input + 1234
            end
            c = PropCheck::Property::CheckEvaluator.new({y: 2}) do
              x = call_me(y)
            end
            expect(c.respond_to?(:call_me)).to be true
            c.call

            expect(x).to be(1234 + 2)
          end.not_to raise_error
        end
      end

      describe ".configure" do
        it "configures all checks done from that point onward" do
          PropCheck::Property.configure do |config|
            config.n_runs = 42
          end

          expect(PropCheck::forall(foo: PropCheck::Generators.integer).configuration.n_runs).to be 42
        end
      end
    end
    describe RSpec do
      require 'prop_check/rspec'
      extend PropCheck::RSpec
      it "adds forall to the example scope" do
        thing = nil
        forall(x: PropCheck::Generators.integer) do
          expect(x).to be_a(Integer)
          thing = true
        end
        expect(thing).to be true
      end

      describe "the hooks" do
        include ::PropCheck::RSpec
        # p method(:before)
        # p ancestors
        outer_val = 0
        before(:each_prop_check_iteration) do
          outer_val = x
        end
        it "runs before and after hooks with `:each_prop_check_iteration` context before/after each PropCheck iteration." do
          forall(x: PropCheck::Generators.integer) do
            expect(outer_val).to be x
          end
        end
      end
    end
  end
end
