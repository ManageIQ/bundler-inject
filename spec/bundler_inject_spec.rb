RSpec.describe Bundler::Inject do
  let(:base_gemfile) do
    bundler_inject_root = Pathname.new(__dir__).join("..").expand_path

    <<~G
      source "https://rubygems.org"

      plugin "bundler-inject", :git => #{bundler_inject_root.to_s.inspect}, :ref => "HEAD"
      require File.join(Bundler::Plugin.index.load_paths("bundler-inject")[0], "bundler-inject") rescue nil

      gem "rack", "=2.0.6"
    G
  end

  shared_examples_for "overrides" do
    it "with local overrides" do
      write_bundler_d_file <<~F
        gem "rack-obama"
      F
      bundle(:update)

      expect(out).to match %r{^Injecting .+/bundler\.d/local_overrides\.rb\.\.\.$}
      expect(lockfile_specs).to match_array [["rack", "2.0.6"], ["rack-obama", "0.1.1"]]
    end

    it "with global overrides" do
      write_global_bundler_d_file <<~F
        gem "rack-obama"
      F
      bundle(:update)

      expect(out).to match %r{^Injecting .+/.bundler\.d/global_overrides\.rb\.\.\.$}
      expect(lockfile_specs).to match_array [["rack", "2.0.6"], ["rack-obama", "0.1.1"]]
    end

    it "with local and global overrides" do
      write_bundler_d_file <<~F
        gem "rack-obama"
      F
      write_global_bundler_d_file <<~F
        gem "omg"
      F
      bundle(:update)

      expect(out).to match %r{^Injecting .+/bundler\.d/local_overrides\.rb\.\.\.$}
      expect(out).to match %r{^Injecting .+/.bundler\.d/global_overrides\.rb\.\.\.$}
      expect(lockfile_specs).to match_array [["rack", "2.0.6"], ["rack-obama", "0.1.1"], ["omg", "0.0.6"]]
    end

    it "only outputs \"Injecting\" in verbose mode" do
      write_bundler_d_file <<~F
        gem "rack-obama"
      F
      write_global_bundler_d_file <<~F
        gem "omg"
      F
      bundle(:update, verbose: false)

      expect(out).to_not match %r{^Injecting .+/bundler\.d/local_overrides\.rb\.\.\.$}
      expect(out).to_not match %r{^Injecting .+/.bundler\.d/global_overrides\.rb\.\.\.$}
      expect(lockfile_specs).to match_array [["rack", "2.0.6"], ["rack-obama", "0.1.1"], ["omg", "0.0.6"]]
    end

    describe "#override_gem" do
      it "with a different version" do
        write_bundler_d_file <<~F
          override_gem "rack", "=2.0.5"
        F
        bundle(:update)

        expect(lockfile_specs).to eq [["rack", "2.0.5"]]
        expect(err).to match %r{^\*\* override_gem\("rack", "=2.0.5"\) at .+/bundler\.d/local_overrides.rb:1$}
      end

      it "with a git repo" do
        write_bundler_d_file <<~F
          override_gem "rack", :git => "https://github.com/rack/rack"
        F
        bundle(:update)

        expect(lockfile_specs).to eq [["rack", extract_rack_version]]
        expect(err).to match %r{^\*\* override_gem\("rack", :git=>"https://github.com/rack/rack"\) at .+/bundler\.d/local_overrides.rb:1$}
      end

      it "with a path" do
        with_path_based_gem("https://github.com/rack/rack") do |path|
          write_bundler_d_file <<~F
            override_gem "rack", :path => #{path.to_s.inspect}
          F
          bundle(:update)

          expect(lockfile_specs).to eq [["rack", extract_rack_version(path)]]
          expect(err).to match %r{^\*\* override_gem\("rack", :path=>#{path.to_s.inspect}\) at .+/bundler\.d/local_overrides.rb:1$}
        end
      end

      it "with a path that includes ~" do
        with_path_based_gem("https://github.com/rack/rack") do |path|
          path = Pathname.new("~/#{path.relative_path_from(Pathname.new("~").expand_path)}")

          write_bundler_d_file <<~F
            override_gem "rack", :path => #{path.to_s.inspect}
          F
          bundle(:update)

          expect(lockfile_specs).to eq [["rack", extract_rack_version(path.expand_path)]]
          expect(err).to match %r{^\*\* override_gem\("rack", :path=>#{path.expand_path.to_s.inspect}\) at .+/bundler\.d/local_overrides.rb:1$}
        end
      end

      it "when the gem doesn't exist" do
        write_bundler_d_file <<~F
          override_gem "omg"
        F
        bundle(:update, expect_error: true)

        stream = bundler_short_version == "2.0" ? err : out
        expect(stream).to include "Trying to override unknown gem \"omg\""
      end
    end

    describe "#ensure_gem" do
      it "when the gem doesn't exist" do
        write_global_bundler_d_file <<~F
          ensure_gem "omg"
        F
        bundle(:update)

        expect(lockfile_specs).to match_array [["rack", "2.0.6"], ["omg", "0.0.6"]]
        expect(err).to_not match %r{^\*\* override_gem}
      end

      it "when overriding without a version" do
        write_global_bundler_d_file <<~F
          ensure_gem "rack"
        F
        bundle(:update)

        expect(lockfile_specs).to eq [["rack", "2.0.6"]]
        expect(err).to_not match %r{^\*\* override_gem}
      end

      it "when overriding with the same version" do
        write_global_bundler_d_file <<~F
          ensure_gem "rack", "=2.0.6"
        F
        bundle(:update)

        expect(lockfile_specs).to eq [["rack", "2.0.6"]]
        expect(err).to_not match %r{^\*\* override_gem}
      end

      it "when overriding with a different version" do
        write_global_bundler_d_file <<~F
          ensure_gem "rack", "=2.0.5"
        F
        bundle(:update)

        expect(lockfile_specs).to eq [["rack", "2.0.5"]]
        expect(err).to match %r{^\*\* override_gem\("rack", "=2.0.5"\) at .+/\.bundler\.d/global_overrides.rb:1$}
      end

      it "when overriding with other options" do
        write_global_bundler_d_file <<~F
          override_gem "rack", :git => "https://github.com/rack/rack"
        F
        bundle(:update)

        expect(lockfile_specs).to eq [["rack", extract_rack_version]]
        expect(err).to match %r{^\*\* override_gem\("rack", :git=>"https://github.com/rack/rack"\) at .+/\.bundler\.d/global_overrides.rb:1$}
      end
    end
  end

  context "on initial update" do
    before do
      write_gemfile(base_gemfile)
    end

    it "installs the plugin" do
      bundle(:update)

      expect(out).to include "Using bundler-inject #{Bundler::Inject::VERSION}"
      expect(out).to include "Installed plugin bundler-inject"
    end

    it "with no overrides" do
      bundle(:update)

      expect(out).to_not match /^Injecting /
      expect(lockfile_specs).to eq [["rack", "2.0.6"]]
    end

    include_examples "overrides"
  end

  context "after initial update" do
    before do
      write_gemfile(base_gemfile)
      bundle(:update)
    end

    it "does not reinstall the plugin" do
      bundle(:update)

      expect(out).to include "Using bundler-inject #{Bundler::Inject::VERSION}"
      expect(out).to_not include "Installed plugin bundler-inject"
    end

    it "with no overrides" do
      bundle(:update)

      expect(out).to_not match /^Injecting /
      expect(lockfile_specs).to eq [["rack", "2.0.6"]]
    end

    include_examples "overrides"
  end
end
