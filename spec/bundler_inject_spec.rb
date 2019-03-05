RSpec.describe Bundler::Inject do
  let(:base_gemfile) do
    bundler_inject_root = Pathname.new(__dir__).join("..").expand_path

    <<~G.chomp
      source "https://rubygems.org"

      plugin "bundler-inject", :git => #{bundler_inject_root.to_s.inspect}, :ref => "HEAD"
      require File.join(Bundler::Plugin.index.load_paths("bundler-inject")[0], "bundler-inject") rescue nil
    G
  end

  shared_examples_for "bundle update" do
    context "bundle update" do
      describe "printing \"Injecting\"..." do
        let(:injecting_local_override)  { %r{^Injecting .+/bundler\.d/local_overrides\.rb\.\.\.$} }
        let(:injecting_global_override) { %r{^Injecting .+/\.bundler\.d/global_overrides\.rb\.\.\.$} }

        it "without verbose" do
          write_bundler_d_file ""
          write_global_bundler_d_file ""
          bundle(:update)

          expect(out).to_not match injecting_local_override
          expect(out).to_not match injecting_global_override
        end

        it "with verbose" do
          write_bundler_d_file ""
          write_global_bundler_d_file ""
          bundle(:update, verbose: true)

          expect(out).to match injecting_local_override
          expect(out).to match injecting_global_override
        end

        it "with local file only" do
          write_bundler_d_file ""
          bundle(:update, verbose: true)

          expect(out).to match injecting_local_override
          expect(out).to_not match injecting_global_override
        end

        it "with global file only" do
          write_global_bundler_d_file ""
          bundle(:update, verbose: true)

          expect(out).to_not match injecting_local_override
          expect(out).to match injecting_global_override
        end

        it "with no files to inject" do
          bundle(:update, verbose: true)

          expect(out).to_not match /^Injecting /
          expect(lockfile_specs).to eq [["rack", "2.0.6"]]
        end
      end

      describe "#gem" do
        it "with local file" do
          write_bundler_d_file <<~F
            gem "rack-obama"
          F
          bundle(:update)

          expect(lockfile_specs).to match_array [["rack", "2.0.6"], ["rack-obama", "0.1.1"]]
        end

        it "with global file" do
          write_global_bundler_d_file <<~F
            gem "rack-obama"
          F
          bundle(:update)

          expect(lockfile_specs).to match_array [["rack", "2.0.6"], ["rack-obama", "0.1.1"]]
        end

        it "with local and global files" do
          write_bundler_d_file <<~F
            gem "rack-obama"
          F
          write_global_bundler_d_file <<~F
            gem "omg"
          F
          bundle(:update)

          expect(lockfile_specs).to match_array [["rack", "2.0.6"], ["rack-obama", "0.1.1"], ["omg", "0.0.6"]]
        end
      end

      describe "#override_gem" do
        it "with a different version" do
          write_bundler_d_file <<~F
            override_gem "rack", "=2.0.5"
          F
          bundle(:update)

          expect(lockfile_specs).to eq [["rack", "2.0.5"]]
          expect(err).to match %r{^\*\* override_gem\("rack", "=2.0.5"\) at .+/bundler\.d/local_overrides\.rb:1$}
        end

        it "with a git repo" do
          write_bundler_d_file <<~F
            override_gem "rack", :git => "https://github.com/rack/rack"
          F
          bundle(:update)

          expect(lockfile_specs).to eq [["rack", extract_rack_version]]
          expect(err).to match %r{^\*\* override_gem\("rack", :git=>"https://github.com/rack/rack"\) at .+/bundler\.d/local_overrides\.rb:1$}
        end

        it "with a path" do
          with_path_based_gem("https://github.com/rack/rack") do |path|
            write_bundler_d_file <<~F
              override_gem "rack", :path => #{path.to_s.inspect}
            F
            bundle(:update)

            expect(lockfile_specs).to eq [["rack", extract_rack_version(path)]]
            expect(err).to match %r{^\*\* override_gem\("rack", :path=>#{path.to_s.inspect}\) at .+/bundler\.d/local_overrides\.rb:1$}
          end
        end

        it "with a path that includes ~" do
          with_path_based_gem("https://github.com/rack/rack") do |path|
            path = Pathname.new("~/#{path.relative_path_from(Pathname.new("~").expand_path)}")

            write_bundler_d_file <<~F
              override_gem "rack", :path => #{path.to_s.inspect}
            F
            bundle(:update)

            expect(lockfile_specs).to eq [["rack", extract_rack_version(path)]]
            expect(err).to match %r{^\*\* override_gem\("rack", :path=>#{path.expand_path.to_s.inspect}\) at .+/bundler\.d/local_overrides\.rb:1$}
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

        it "with ENV['RAILS_ENV'] = 'production'" do
          write_bundler_d_file <<~F
            override_gem "rack", "=2.0.5"
          F
          bundle(:update, env: { "RAILS_ENV" => "production" })

          expect(lockfile_specs).to eq [["rack", "2.0.5"]]
          expect(err).to_not match %r{^\*\* override_gem}
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
          expect(err).to match %r{^\*\* override_gem\("rack", "=2.0.5"\) at .+/\.bundler\.d/global_overrides\.rb:1$}
        end

        it "when overriding with other options" do
          write_global_bundler_d_file <<~F
            override_gem "rack", :git => "https://github.com/rack/rack"
          F
          bundle(:update)

          expect(lockfile_specs).to eq [["rack", extract_rack_version]]
          expect(err).to match %r{^\*\* override_gem\("rack", :git=>"https://github.com/rack/rack"\) at .+/\.bundler\.d/global_overrides\.rb:1$}
        end
      end
    end
  end

  shared_examples_for "bundle check/exec" do
    context "bundle check/exec" do
      let(:exec_command) do
        %q{ruby -e "puts Bundler.environment.gems.select { |g| %w[rack rack-obama omg].include?(g.name) }.map { |g| [g.name, g.version.version] }.sort.inspect"}
      end

      describe "#gem" do
        before do
          write_bundler_d_file <<~F
            gem "rack-obama"
          F
          write_global_bundler_d_file <<~F
            gem "omg"
          F
          bundle(:update)
        end

        it "bundle check" do
          bundle(:check)

          expect(out).to eq "The Gemfile's dependencies are satisfied\n"
          expect(err).to be_empty
        end

        it "bundle exec" do
          bundle("exec #{exec_command}")

          expect(out).to eq %Q{[["omg", "0.0.6"], ["rack", "2.0.6"], ["rack-obama", "0.1.1"]]\n}
          expect(err).to be_empty
        end
      end

      describe "#override_gem" do
        before do
          write_bundler_d_file <<~F
            override_gem "rack", "=2.0.5"
            gem "rack-obama"
          F
          write_global_bundler_d_file <<~F
            gem "omg"
          F
          bundle(:update)
        end

        it "bundle check" do
          bundle(:check)

          expect(out).to eq "The Gemfile's dependencies are satisfied\n"
          expect(err).to match %r{\A\*\* override_gem\("rack", "=2.0.5"\) at .+/bundler\.d/local_overrides\.rb:1\n\z}
        end

        it "bundle exec" do
          bundle("exec #{exec_command}")

          expect(out).to eq %Q{[["omg", "0.0.6"], ["rack", "2.0.5"], ["rack-obama", "0.1.1"]]\n}
          expect(err).to match %r{\A\*\* override_gem\("rack", "=2.0.5"\) at .+/bundler\.d/local_overrides\.rb:1\n\z}
        end
      end

      describe "#ensure_gem" do
        before do
          write_bundler_d_file <<~F
            gem "omg"
            gem "rack-obama"
          F
          write_global_bundler_d_file <<~F
            ensure_gem "rack", "=2.0.5"
          F
          bundle(:update)
        end

        it "bundle check" do
          bundle(:check)

          expect(out).to eq "The Gemfile's dependencies are satisfied\n"
          expect(err).to match %r{\A\*\* override_gem\("rack", "=2.0.5"\) at .+/\.bundler\.d/global_overrides\.rb:1\n\z}
        end

        it "bundle exec" do
          bundle("exec #{exec_command}")

          expect(out).to eq %Q{[["omg", "0.0.6"], ["rack", "2.0.5"], ["rack-obama", "0.1.1"]]\n}
          expect(err).to match %r{\A\*\* override_gem\("rack", "=2.0.5"\) at .+/\.bundler\.d/global_overrides\.rb:1\n\z}
        end
      end
    end
  end

  context "on initial update" do
    before do
      write_gemfile <<~G
        #{base_gemfile}

        gem "rack", "=2.0.6"
      G
    end

    it "installs the plugin" do
      bundle(:update)

      expect(out).to include "Using bundler-inject #{Bundler::Inject::VERSION}"
      expect(out).to include "Installed plugin bundler-inject"
    end

    include_examples "bundle update"
    include_examples "bundle check/exec"
  end

  context "after initial update" do
    before do
      write_gemfile <<~G
        #{base_gemfile}

        gem "rack", "=2.0.6"
      G
      bundle(:update)
    end

    it "does not reinstall the plugin" do
      bundle(:update)

      expect(out).to include "Using bundler-inject #{Bundler::Inject::VERSION}"
      expect(out).to_not include "Installed plugin bundler-inject"
    end

    include_examples "bundle update"
    include_examples "bundle check/exec"
  end

  context "with a git-based gem in the base Gemfile" do
    before do
      write_gemfile <<~G
        #{base_gemfile}

        gem "rack", :git => "https://github.com/rack/rack"
      G
    end

    describe "#override_gem" do
      it "will remove the original git source" do
        write_bundler_d_file <<~F
          override_gem "rack", "=2.0.6"
        F
        bundle(:update)

        expect(lockfile_specs).to eq [["rack", "2.0.6"]]
        expect(err).to match %r{^\*\* override_gem\("rack", "=2.0.6"\) at .+/bundler\.d/local_overrides\.rb:1$}

        expect(lockfile.sources.map(&:class)).to_not include(Bundler::Source::Git)
      end
    end
  end
end
