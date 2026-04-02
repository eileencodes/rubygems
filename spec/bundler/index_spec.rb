# frozen_string_literal: true

RSpec.describe Bundler::Index do
  let(:specs) { [] }
  subject { described_class.build {|i| i.use(specs) } }

  context "specs with a nil platform" do
    let(:spec) do
      Gem::Specification.new do |s|
        s.name = "json"
        s.version = "1.8.3"
        allow(s).to receive(:platform).and_return(nil)
      end
    end
    let(:specs) { [spec] }

    describe "#search_by_spec" do
      it "finds the spec when a nil platform is specified" do
        expect(subject.search(spec)).to eq([spec])
      end

      it "finds the spec when a ruby platform is specified" do
        query = spec.dup.tap {|s| s.platform = "ruby" }
        expect(subject.search(query)).to eq([spec])
      end
    end
  end

  context "with specs that include development dependencies" do
    let(:specs) { [*build_spec("a", "1.0.0") {|s| s.development("b", "~> 1.0") }] }

    it "does not include b in #dependency_names" do
      expect(subject.dependency_names).not_to include("b")
    end
  end

  describe "#name_version_pairs" do
    let(:specs) do
      [
        *build_spec("foo", "1.0.0"),
        *build_spec("foo", "1.0.0", "x86_64-linux"),
        *build_spec("bar", "2.0.0"),
      ]
    end

    it "returns a Set of [name, version] pairs" do
      pairs = subject.name_version_pairs
      expect(pairs).to be_a(Set)
      expect(pairs).to include(["foo", Gem::Version.new("1.0.0")])
      expect(pairs).to include(["bar", Gem::Version.new("2.0.0")])
    end

    it "deduplicates across platforms" do
      pairs = subject.name_version_pairs
      foo_pairs = pairs.select {|name, _| name == "foo" }
      expect(foo_pairs.size).to eq 1
    end

    it "returns empty set for empty index" do
      empty_index = described_class.build {|i| }
      expect(empty_index.name_version_pairs).to be_empty
    end
  end
end
