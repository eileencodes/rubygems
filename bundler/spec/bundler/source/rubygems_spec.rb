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

  describe "#pre_download" do
    it "fetches all gems before installing any" do
      build_repo2 do
        build_gem "activesupport", "1.0.0"
        build_gem "activerecord", "1.0.0" do |s|
          s.add_dependency "activesupport", "1.0.0"
        end
      end

      stdout = install_gemfile(<<~G, verbose: true)
        source "https://gem.repo2"
        gem "activerecord"
      G

      lines = stdout.lines
      fetching_lines = lines.select {|l| l.include?("Fetching") }
      installing_lines = lines.select {|l| l.include?("Installing") }

      expect(fetching_lines).not_to be_empty
      expect(installing_lines).not_to be_empty

      last_fetch_index = lines.index(fetching_lines.last)
      first_install_index = lines.index(installing_lines.first)

      expect(last_fetch_index).to be < first_install_index
    end

    it "does not re-fetch gems that are already installed" do
      build_repo2 do
        build_gem "foo", "1.0.0"
      end

      install_gemfile <<~G
        source "https://gem.repo2"
        gem "foo"
      G

      stdout = install_gemfile(<<~G, verbose: true)
        source "https://gem.repo2"
        gem "foo"
      G

      expect(stdout).not_to include("Fetching foo")
      expect(stdout).to include("Using foo")
    end
  end

  describe "#pre_unpack" do
    it "extracts gems before the install phase" do
      build_repo4 do
        build_gem "mygem_a", "1.0.0"
        build_gem "mygem_b", "1.0.0" do |s|
          s.add_dependency "mygem_a", "1.0.0"
        end
      end

      stdout = install_gemfile(<<~G, verbose: true)
        source "https://gem.repo4"
        gem "mygem_b"
      G

      # All gems should be fetched and installed successfully
      expect(stdout).to include("Installing mygem_a 1.0.0")
      expect(stdout).to include("Installing mygem_b 1.0.0")
    end

    it "installs gems with native extensions correctly after pre-unpack" do
      build_repo4 do
        build_gem "native_gem", "1.0.0" do |s|
          s.extensions << "ext/extconf.rb"
          s.write "ext/extconf.rb", <<-RUBY
            require "mkmf"
            create_makefile("native_gem")
          RUBY
          s.write "ext/native_gem.c", "void Init_native_gem(void) {}"
        end
      end

      stdout = install_gemfile(<<~G, verbose: true)
        source "https://gem.repo4"
        gem "native_gem"
      G

      expect(stdout).to include("Installing native_gem 1.0.0 with native extensions")
    end

    it "does not re-extract gems that are already installed" do
      build_repo4 do
        build_gem "mygem", "1.0.0"
      end

      install_gemfile <<~G
        source "https://gem.repo4"
        gem "mygem"
      G

      stdout = install_gemfile(<<~G, verbose: true)
        source "https://gem.repo4"
        gem "mygem"
      G

      expect(stdout).not_to include("Installing mygem")
      expect(stdout).to include("Using mygem")
    end
  end
end
