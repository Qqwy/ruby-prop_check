RSpec.describe PropCheck do
  it "has a version number" do
    expect(PropCheck::VERSION).not_to be nil
  end

  describe "PropCheck" do
    describe ".forall" do
      it "returns a Property when called without a block" do
        expect(PropCheck.forall(x: PropCheck::Generators.integer)).to be_a(PropCheck::Property)
      end

      it "runs the property test when called with a block" do
        expect { |block| PropCheck.forall(x: PropCheck::Generators.integer, &block) }.to yield_control
      end
    end

    describe "Property" do
      describe "#with_settings" do
        it "updates the settings" do
          p = PropCheck.forall(x: PropCheck::Generators.integer)
          expect(p.settings[:verbose]).to be false
          expect(p.with_settings(verbose: true).settings[:verbose]).to be true
        end
        it "Runs the property test when called with a block" do
          expect { |block| PropCheck.forall(x: PropCheck::Generators.integer).with_settings({}, &block) }.to yield_control
        end
      end

      describe "#check" do
        it "generates an error that Rspec can pick up" do
          expect do
            PropCheck.forall(x: PropCheck::Generators.integer) do
              expect(x).to be < 100
            end
          end.to raise_error do |error|
            expect(error).to be_a(RSpec::Expectations::ExpectationNotMetError)
            expect(error.message).to match(/\(after \d+ successful property test runs\)/m)
            expect(error.message).to match(/Exception message:/m)

            # Test basic shrinking real quick:
            expect(error.message).to match(/Shrunken input \(after \d+ shrink steps\):\n`x = 100`/m)
            expect(error.message).to match(/Shrunken exception:/m)
          end
        end
      end
    end
  end
end
