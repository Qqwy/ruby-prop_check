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
        # expect(
        #   PropCheck.forall(x: PropCheck::Generators.integer).with_settings(verbose: true) do
        #     true
        #   end
        # ).to be nil
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

      it "works" do
        PropCheck.forall(x: PropCheck::Generators.integer) do
          expect(x).to be < 100
        end
      end
    end
  end

end

