# The gem versions used in these specs follow a specific pattern in order to
# test various versions and overrides. rubytest 0.7.0 depends on ansi >= 0 which
# has no dependencies.  This allows us to manipulate the various versions of
# ansi without introducing additional dependencies complicating the test.
# ansi 1.4.2, 1.4.3, 1.5.0 are the three latest versions, and most tests "start"
# with ansi 1.4.3 in the base Gemfile. omg 0.0.6 is an additional gem that also
# has no dependencies.
RSpec.describe Bundler::Inject do
  let(:bundler_inject_root) { Pathname.new(__dir__).join("..").expand_path.to_s }
  let(:base_gemfile) do
    <<~G.chomp
      source "https://rubygems.org"

      plugin "bundler-inject", :git => #{bundler_inject_root.inspect}, :ref => "HEAD"
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
          expect(lockfile_specs).to eq [["ansi", "1.4.3"]]
        end
      end

      describe "#gem" do
        it "with local file" do
          write_bundler_d_file <<~F
            gem "rubytest", "=0.7.0"
          F
          bundle(:update)

          expect(lockfile_specs).to match_array [["ansi", "1.4.3"], ["rubytest", "0.7.0"]]
        end

        it "with global file" do
          write_global_bundler_d_file <<~F
            gem "rubytest", "=0.7.0"
          F
          bundle(:update)

          expect(lockfile_specs).to match_array [["ansi", "1.4.3"], ["rubytest", "0.7.0"]]
        end

        it "with local and global files" do
          write_bundler_d_file <<~F
            gem "rubytest", "=0.7.0"
          F
          write_global_bundler_d_file <<~F
            gem "omg"
          F
          bundle(:update)

          expect(lockfile_specs).to match_array [["ansi", "1.4.3"], ["rubytest", "0.7.0"], ["omg", "0.0.6"]]
        end
      end

      describe "#override_gem" do
        it "with a different version" do
          write_bundler_d_file <<~F
            override_gem "ansi", "=1.4.2"
          F
          bundle(:update)

          expect(lockfile_specs).to eq [["ansi", "1.4.2"]]
          expect(err).to match %r{^\*\* override_gem\("ansi", "=1.4.2"\) at .+/bundler\.d/local_overrides\.rb:1$}
        end

        it "with a git repo" do
          write_bundler_d_file <<~F
            override_gem "ansi", :git => "https://github.com/rubyworks/ansi"
          F
          bundle(:update)

          expect(lockfile_specs).to eq [["ansi", "1.5.0"]]
          expect(err).to match %r{^\*\* override_gem\("ansi", :git=>"https://github.com/rubyworks/ansi"\) at .+/bundler\.d/local_overrides\.rb:1$}
        end

        it "with a path" do
          with_path_based_gem("https://github.com/rubyworks/ansi") do |path|
            write_bundler_d_file <<~F
              override_gem "ansi", :path => #{path.to_s.inspect}
            F
            bundle(:update)

            expect(lockfile_specs).to eq [["ansi", "1.5.0"]]
            expect(err).to match %r{^\*\* override_gem\("ansi", :path=>#{path.to_s.inspect}\) at .+/bundler\.d/local_overrides\.rb:1$}
          end
        end

        it "with a path that includes ~" do
          with_path_based_gem("https://github.com/rubyworks/ansi") do |path|
            path = Pathname.new("~/#{path.relative_path_from(Pathname.new("~").expand_path)}")

            write_bundler_d_file <<~F
              override_gem "ansi", :path => #{path.to_s.inspect}
            F
            bundle(:update)

            expect(lockfile_specs).to eq [["ansi", "1.5.0"]]
            expect(err).to match %r{^\*\* override_gem\("ansi", :path=>#{path.expand_path.to_s.inspect}\) at .+/bundler\.d/local_overrides\.rb:1$}
          end
        end

        it "when the gem doesn't exist" do
          write_bundler_d_file <<~F
            override_gem "omg"
          F
          bundle(:update, expect_error: true)

          expect(err).to include "Trying to override unknown gem \"omg\""
        end

        it "with ENV['BUNDLE_BUNDLER_INJECT__DISABLE_WARN_OVERRIDE_GEM'] = 'true'" do
          write_bundler_d_file <<~F
            override_gem "ansi", "=1.4.2"
          F
          env_var = "BUNDLE_BUNDLER_INJECT__DISABLE_WARN_OVERRIDE_GEM"
          bundle(:update, env: { env_var => "true" })

          expect(lockfile_specs).to eq [["ansi", "1.4.2"]]
          expect(err).to_not match %r{^\*\* override_gem}
        end

        it "with ENV['RAILS_ENV'] = 'production'" do
          write_bundler_d_file <<~F
            override_gem "ansi", "=1.4.2"
          F
          bundle(:update, env: { "RAILS_ENV" => "production" })

          expect(lockfile_specs).to eq [["ansi", "1.4.2"]]
          expect(err).to_not match %r{^\*\* override_gem}
        end

        it "with ENV['RAILS_ENV'] = 'production' and the Bundler::Setting false" do
          write_bundler_d_file <<~F
            override_gem "ansi", "=1.4.2"
          F
          env_var = "BUNDLE_BUNDLER_INJECT__DISABLE_WARN_OVERRIDE_GEM"
          bundle(:update, env: { "RAILS_ENV" => "production", env_var => 'false' })

          expect(lockfile_specs).to eq [["ansi", "1.4.2"]]
          expect(err).to match %r{^\*\* override_gem\("ansi", "=1.4.2"\) at .+/bundler\.d/local_overrides\.rb:1$}
        end
      end

      describe "#ensure_gem" do
        it "when the gem doesn't exist" do
          write_global_bundler_d_file <<~F
            ensure_gem "omg"
          F
          bundle(:update)

          expect(lockfile_specs).to match_array [["ansi", "1.4.3"], ["omg", "0.0.6"]]
          expect(err).to_not match %r{^\*\* override_gem}
        end

        it "when overriding without a version" do
          write_global_bundler_d_file <<~F
            ensure_gem "ansi"
          F
          bundle(:update)

          expect(lockfile_specs).to eq [["ansi", "1.4.3"]]
          expect(err).to_not match %r{^\*\* override_gem}
        end

        it "when overriding with the same version" do
          write_global_bundler_d_file <<~F
            ensure_gem "ansi", "=1.4.3"
          F
          bundle(:update)

          expect(lockfile_specs).to eq [["ansi", "1.4.3"]]
          expect(err).to_not match %r{^\*\* override_gem}
        end

        it "when overriding with a different version" do
          write_global_bundler_d_file <<~F
            ensure_gem "ansi", "=1.4.2"
          F
          bundle(:update)

          expect(lockfile_specs).to eq [["ansi", "1.4.2"]]
          expect(err).to match %r{^\*\* override_gem\("ansi", "=1.4.2"\) at .+/\.bundler\.d/global_overrides\.rb:1$}
        end

        it "when overriding with other options" do
          write_global_bundler_d_file <<~F
            override_gem "ansi", :git => "https://github.com/rubyworks/ansi"
          F
          bundle(:update)

          expect(lockfile_specs).to eq [["ansi", "1.5.0"]]
          expect(err).to match %r{^\*\* override_gem\("ansi", :git=>"https://github.com/rubyworks/ansi"\) at .+/\.bundler\.d/global_overrides\.rb:1$}
        end
      end
    end
  end

  shared_examples_for "bundle check/exec" do
    context "bundle check/exec" do
      let(:exec_command) do
        %q{ruby -e "puts Bundler.load.gems.select { |g| %w[ansi rubytest omg].include?(g.name) }.map { |g| [g.name, g.version.version] }.sort.inspect"}
      end

      describe "#gem" do
        before do
          write_bundler_d_file <<~F
            gem "rubytest", "=0.7.0"
          F
          write_global_bundler_d_file <<~F
            gem "omg"
          F
          bundle(:update)
        end

        it "bundle check" do
          bundle(:check)

          expect(out).to eq "The Gemfile's dependencies are satisfied\n"
          expect(err).to_not match %r{^\*\* override_gem}
        end

        it "bundle exec" do
          bundle("exec #{exec_command}")

          expect(out).to eq %Q{[["ansi", "1.4.3"], ["omg", "0.0.6"], ["rubytest", "0.7.0"]]\n}
          expect(err).to_not match %r{^\*\* override_gem}
        end
      end

      describe "#override_gem" do
        before do
          write_bundler_d_file <<~F
            override_gem "ansi", "=1.4.2"
            gem "rubytest", "=0.7.0"
          F
          write_global_bundler_d_file <<~F
            gem "omg"
          F
          bundle(:update)
        end

        it "bundle check" do
          bundle(:check)

          expect(out).to eq "The Gemfile's dependencies are satisfied\n"
          expect(err).to match %r{^\*\* override_gem\("ansi", "=1.4.2"\) at .+/bundler\.d/local_overrides\.rb:1\n$}
        end

        it "bundle exec" do
          bundle("exec #{exec_command}")

          expect(out).to eq %Q{[["ansi", "1.4.2"], ["omg", "0.0.6"], ["rubytest", "0.7.0"]]\n}
          expect(err).to match %r{^\*\* override_gem\("ansi", "=1.4.2"\) at .+/bundler\.d/local_overrides\.rb:1\n$}
        end
      end

      describe "#ensure_gem" do
        before do
          write_bundler_d_file <<~F
            gem "omg"
            gem "rubytest", "=0.7.0"
          F
          write_global_bundler_d_file <<~F
            ensure_gem "ansi", "=1.4.2"
          F
          bundle(:update)
        end

        it "bundle check" do
          bundle(:check)

          expect(out).to eq "The Gemfile's dependencies are satisfied\n"
          expect(err).to match %r{^\*\* override_gem\("ansi", "=1.4.2"\) at .+/\.bundler\.d/global_overrides\.rb:1\n$}
        end

        it "bundle exec" do
          bundle("exec #{exec_command}")

          expect(out).to eq %Q{[["ansi", "1.4.2"], ["omg", "0.0.6"], ["rubytest", "0.7.0"]]\n}
          expect(err).to match %r{^\*\* override_gem\("ansi", "=1.4.2"\) at .+/\.bundler\.d/global_overrides\.rb:1\n$}
        end
      end
    end
  end

  context "on initial update" do
    before do
      write_gemfile <<~G
        #{base_gemfile}

        gem "ansi", "=1.4.3"
      G
    end

    it "installs the plugin" do
      bundle(:update)

      expect(out).to include("Fetching #{bundler_inject_root}")

      # bundler 2.4.17 removed the "Using" statements in https://github.com/rubygems/rubygems/pull/6804
      if Gem::Version.new(bundler_version) < Gem::Version.new("2.4.17")
        expect(out).to include "Using bundler-inject #{Bundler::Inject::VERSION}"
      end

      expect(out).to include "Installed plugin bundler-inject"
    end

    include_examples "bundle update"
    include_examples "bundle check/exec"
  end

  context "after initial update" do
    before do
      write_gemfile <<~G
        #{base_gemfile}

        gem "ansi", "=1.4.3"
      G
      bundle(:update)
    end

    it "does not reinstall the plugin" do
      bundle(:update)

      expect(out).to include("Fetching #{bundler_inject_root}")

      # bundler 2.4.17 removed the "Using" statements in https://github.com/rubygems/rubygems/pull/6804
      if Gem::Version.new(bundler_version) < Gem::Version.new("2.4.17")
        expect(out).to include "Using bundler-inject #{Bundler::Inject::VERSION}"
      end

      expect(out).to_not include "Installed plugin bundler-inject"
    end

    include_examples "bundle update"
    include_examples "bundle check/exec"
  end

  context "with a git-based gem in the base Gemfile" do
    before do
      write_gemfile <<~G
        #{base_gemfile}

        gem "ansi", :git => "https://github.com/rubyworks/ansi"
      G
    end

    describe "#override_gem" do
      it "will remove the original git source" do
        write_bundler_d_file <<~F
          override_gem "ansi", "=1.4.3"
        F
        bundle(:update)

        expect(lockfile_specs).to eq [["ansi", "1.4.3"]]
        expect(err).to match %r{^\*\* override_gem\("ansi", "=1.4.3"\) at .+/bundler\.d/local_overrides\.rb:1$}

        expect(lockfile.sources.map(&:class)).to_not include(Bundler::Source::Git)
      end
    end
  end
end
