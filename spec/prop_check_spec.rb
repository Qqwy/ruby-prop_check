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
        expect(
          PropCheck.forall(x: PropCheck::Generators.integer).with_settings(verbose: true) do
            true
          end
        ).to be nil
      end
    end
  end
end
