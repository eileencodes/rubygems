# frozen_string_literal: true

require "bundler/installer/parallel_installer"

RSpec.describe Bundler::ParallelInstaller::SpecInstallation do
  def build_spec(name, extensions: [])
    a_spec = Object.new
    a_spec.define_singleton_method(:name) { name }
    a_spec.define_singleton_method(:full_name) { "#{name}-1.0" }
    a_spec.define_singleton_method(:extensions) { extensions }
    a_spec
  end

  let!(:dep) { build_spec("I like tests") }

  describe "#ready_to_enqueue?" do
    context "when in enqueued state" do
      it "is falsey" do
        spec = described_class.new(dep)
        spec.state = :enqueued
        expect(spec.ready_to_enqueue?).to be_falsey
      end
    end

    context "when in installed state" do
      it "returns falsey" do
        spec = described_class.new(dep)
        spec.state = :installed
        expect(spec.ready_to_enqueue?).to be_falsey
      end
    end

    it "returns truthy" do
      spec = described_class.new(dep)
      expect(spec.ready_to_enqueue?).to be_truthy
    end
  end

  describe "#dependencies_installed?" do
    context "when all dependencies are installed" do
      it "returns true" do
        dependencies = []
        dependencies << instance_double("SpecInstallation", spec: "alpha", name: "alpha", installed?: true, all_dependencies: [], type: :production)
        dependencies << instance_double("SpecInstallation", spec: "beta", name: "beta", installed?: true, all_dependencies: [], type: :production)
        all_specs = dependencies + [instance_double("SpecInstallation", spec: "gamma", name: "gamma", installed?: false, all_dependencies: [], type: :production)]
        spec = described_class.new(build_spec("native_gem", extensions: ["ext/extconf.rb"]))
        allow(spec).to receive(:all_dependencies).and_return(dependencies)
        installed_specs = all_specs.select(&:installed?).map {|s| [s.name, true] }.to_h
        expect(spec.dependencies_installed?(installed_specs)).to be_truthy
      end
    end

    context "when all dependencies are not installed" do
      it "returns false" do
        dependencies = []
        dependencies << instance_double("SpecInstallation", spec: "alpha", name: "alpha", installed?: false, all_dependencies: [], type: :production)
        dependencies << instance_double("SpecInstallation", spec: "beta", name: "beta", installed?: true, all_dependencies: [], type: :production)
        all_specs = dependencies + [instance_double("SpecInstallation", spec: "gamma", name: "gamma", installed?: false, all_dependencies: [], type: :production)]
        spec = described_class.new(build_spec("native_gem", extensions: ["ext/extconf.rb"]))
        allow(spec).to receive(:all_dependencies).and_return(dependencies)
        installed_specs = all_specs.select(&:installed?).map {|s| [s.name, true] }.to_h
        expect(spec.dependencies_installed?(installed_specs)).to be_falsey
      end
    end

    context "when gem has no extensions (pure Ruby)" do
      it "returns true regardless of dependency state" do
        dependencies = []
        dependencies << instance_double("SpecInstallation", spec: "alpha", name: "alpha", installed?: false, all_dependencies: [], type: :production)
        spec = described_class.new(build_spec("pure_ruby_gem"))
        allow(spec).to receive(:all_dependencies).and_return(dependencies)
        expect(spec.dependencies_installed?({})).to be_truthy
      end
    end
  end

  describe "#has_extensions?" do
    it "returns true for gems with extensions" do
      spec = described_class.new(build_spec("native", extensions: ["ext/extconf.rb"]))
      expect(spec.has_extensions?).to be true
    end

    it "returns false for pure Ruby gems" do
      spec = described_class.new(build_spec("pure"))
      expect(spec.has_extensions?).to be false
    end
  end
end
