# frozen_string_literal: true

RSpec.describe Bundler::Source::Rubygems do
  before do
    allow(Bundler).to receive(:root) { Pathname.new("root") }
  end

  describe "caches" do
    it "includes Bundler.app_cache" do
      expect(subject.caches).to include(Bundler.app_cache)
    end

    it "includes GEM_PATH entries" do
      Gem.path.each do |path|
        expect(subject.caches).to include(File.expand_path("#{path}/cache"))
      end
    end

    it "is an array of strings or pathnames" do
      subject.caches.each do |cache|
        expect([String, Pathname]).to include(cache.class)
      end
    end
  end

  describe "#add_remote" do
    context "when the source is an HTTP(s) URI with no host" do
      it "raises error" do
        expect { subject.add_remote("https:rubygems.org") }.to raise_error(ArgumentError)
      end
    end
  end

  describe "#add_binary_remote" do
    it "normalizes and stores the URI" do
      subject.add_binary_remote("https://build-farm.example.com")
      expect(subject.binary_remotes).to eq [Gem::URI("https://build-farm.example.com/")]
    end

    it "prepends new binary remotes" do
      subject.add_binary_remote("https://first.example.com")
      subject.add_binary_remote("https://second.example.com")
      expect(subject.binary_remotes).to eq [
        Gem::URI("https://second.example.com/"),
        Gem::URI("https://first.example.com/"),
      ]
    end

    it "does not add duplicates" do
      subject.add_binary_remote("https://build-farm.example.com")
      subject.add_binary_remote("https://build-farm.example.com")
      expect(subject.binary_remotes.size).to eq 1
    end

    context "when the source is an HTTP(s) URI with no host" do
      it "raises error" do
        expect { subject.add_binary_remote("https:build-farm.example.com") }.to raise_error(ArgumentError)
      end
    end
  end

  describe "#no_remotes?" do
    context "when no remote provided" do
      it "returns a truthy value" do
        expect(described_class.new("remotes" => []).no_remotes?).to be_truthy
      end
    end

    context "when a remote provided" do
      it "returns a falsey value" do
        expect(described_class.new("remotes" => ["https://rubygems.org"]).no_remotes?).to be_falsey
      end
    end
  end

  describe "binary remotes in initialize" do
    it "stores binary remotes from options" do
      source = described_class.new(
        "remotes" => ["https://rubygems.org"],
        "binaries" => ["https://build-farm.example.com"]
      )
      expect(source.binary_remotes).to eq [Gem::URI("https://build-farm.example.com/")]
    end

    it "handles multiple binary remotes" do
      source = described_class.new(
        "remotes" => ["https://rubygems.org"],
        "binaries" => ["https://first.example.com", "https://second.example.com"]
      )
      expect(source.binary_remotes.size).to eq 2
    end

    it "defaults to empty binary remotes" do
      source = described_class.new("remotes" => ["https://rubygems.org"])
      expect(source.binary_remotes).to eq []
    end
  end

  describe "#options" do
    it "does not include binaries" do
      source = described_class.new(
        "remotes" => ["https://rubygems.org"],
        "binaries" => ["https://build-farm.example.com"]
      )
      expect(source.options).to eq("remotes" => ["https://rubygems.org/"])
    end
  end

  describe "#eql?" do
    it "considers sources with different binary remotes as not equal" do
      source1 = described_class.new("remotes" => ["https://rubygems.org"])
      source2 = described_class.new(
        "remotes" => ["https://rubygems.org"],
        "binaries" => ["https://build-farm.example.com"]
      )
      expect(source1).not_to eql(source2)
    end

    it "considers sources with same remotes and binary remotes as equal" do
      source1 = described_class.new(
        "remotes" => ["https://rubygems.org"],
        "binaries" => ["https://build-farm.example.com"]
      )
      source2 = described_class.new(
        "remotes" => ["https://rubygems.org"],
        "binaries" => ["https://build-farm.example.com"]
      )
      expect(source1).to eql(source2)
    end
  end

  describe "#hash" do
    it "differs for sources with different binary remotes" do
      source1 = described_class.new("remotes" => ["https://rubygems.org"])
      source2 = described_class.new(
        "remotes" => ["https://rubygems.org"],
        "binaries" => ["https://build-farm.example.com"]
      )
      expect(source1.hash).not_to eq(source2.hash)
    end
  end

  describe "#to_lock" do
    it "includes binary lines" do
      source = described_class.new(
        "remotes" => ["https://rubygems.org"],
        "binaries" => ["https://build-farm.example.com"]
      )
      expected = <<~L
        GEM
          remote: https://rubygems.org/
          binary: https://build-farm.example.com/
          specs:
      L
      expect(source.to_lock).to eq(expected)
    end

    it "includes multiple binary lines" do
      source = described_class.new(
        "remotes" => ["https://rubygems.org"],
        "binaries" => ["https://first.example.com", "https://second.example.com"]
      )
      lock = source.to_lock
      expect(lock).to include("binary: https://first.example.com/")
      expect(lock).to include("binary: https://second.example.com/")
    end

    it "omits binary lines when no binary remotes" do
      source = described_class.new("remotes" => ["https://rubygems.org"])
      expect(source.to_lock).not_to include("binary:")
    end
  end

  describe ".from_lock" do
    it "restores binary remotes from lockfile options" do
      source = described_class.from_lock(
        "remote" => "https://rubygems.org/",
        "binary" => "https://build-farm.example.com/"
      )
      expect(source.binary_remotes).to eq [Gem::URI("https://build-farm.example.com/")]
    end

    it "restores multiple binary remotes from lockfile options" do
      source = described_class.from_lock(
        "remote" => "https://rubygems.org/",
        "binary" => ["https://first.example.com/", "https://second.example.com/"]
      )
      expect(source.binary_remotes.size).to eq 2
    end

    it "handles missing binary key" do
      source = described_class.from_lock("remote" => "https://rubygems.org/")
      expect(source.binary_remotes).to eq []
    end
  end

  describe "to_lock/from_lock round-trip" do
    it "preserves binary remotes" do
      original = described_class.new(
        "remotes" => ["https://rubygems.org"],
        "binaries" => ["https://build-farm.example.com"]
      )

      # Simulate lockfile parser: parse the to_lock output
      lock_output = original.to_lock
      opts = {}
      lock_output.each_line do |line|
        if line =~ /^\s+([a-z]+): (.*)$/i
          key, value = $1, $2
          if opts[key]
            opts[key] = Array(opts[key])
            opts[key] << value
          else
            opts[key] = value
          end
        end
      end

      restored = described_class.from_lock(opts)
      expect(restored.remotes.map(&:to_s)).to eq(original.remotes.map(&:to_s))
      expect(restored.binary_remotes.map(&:to_s)).to eq(original.binary_remotes.map(&:to_s))
    end
  end

  describe "log debug information" do
    it "log the time spent downloading and installing a gem" do
      build_repo2 do
        build_gem "warning"
      end

      gemfile_content = <<~G
        source "https://gem.repo2"
        gem "warning"
      G

      stdout = install_gemfile(gemfile_content, env: { "DEBUG" => "1" })

      expect(stdout).to match(/Downloaded warning in: \d+\.\d+s/)
      expect(stdout).to match(/Installed warning in: \d+\.\d+s/)
    end
  end
end
