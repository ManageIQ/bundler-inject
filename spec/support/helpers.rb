require "tmpdir"
require "open3"

module Spec
  module Helpers
    def self.bundler_versions
      @bundler_versions ||= begin
        versions = with_unbundled_env do
          `gem list bundler`.lines.grep(/^bundler /).first.scan(/\d+\.\d+\.\d+/)
        end
        versions.reject { |v| v < "2" }
      end
    end

    def self.bundler_version
      return @bundler_version if defined?(@bundler_version)

      versions = bundler_versions

      to_find = ENV["TEST_BUNDLER_VERSION"] || ENV["BUNDLER_VERSION"]
      @bundler_version = versions.detect { |v| v.start_with?(to_find.to_s) }
      raise ArgumentError, "Unable to find bundler version: #{to_find.inspect}" if @bundler_version.nil?

      @bundler_version
    end

    def self.bundler_short_version
      bundler_version.rpartition(".").first
    end

    # Ruby gem binstubs allow you to pass a secret version in order to load a
    # bin file for a particular gem version. This is useful when you have
    # multiple versions of a gem installed and only want to invoke a specific
    # one.
    #
    # So, if I have bundler 1.17.3 and 2.0.1 installed, I can run 1.17.3 with:
    #
    #     bundle _1.17.3_ update
    #
    def self.bundler_cli_version
      "_#{bundler_version}_"
    end

    def self.with_unbundled_env(&block)
      # NOTE: Needed for 2.0 support; when we drop 2.0, this method can go away.
      Bundler.send(Bundler.respond_to?(:with_unbundled_env) ? :with_unbundled_env : :with_clean_env, &block)
    end

    def self.global_bundler_d_dir
      @global_bundler_d_dir ||= Pathname.new("~/.bundler.d").expand_path
    end

    def self.global_bundler_d_backup_dir
      @global_bundler_d_backup_dir ||= Pathname.new("~/.bundler.d.rspec_backup").expand_path
    end

    def self.backup_global_bundler_d
      return unless global_bundler_d_dir.exist?

      FileUtils.rm_rf(global_bundler_d_backup_dir)
      FileUtils.mv(global_bundler_d_dir, global_bundler_d_backup_dir)
    end

    def self.restore_global_bundler_d
      return unless global_bundler_d_backup_dir.exist?

      FileUtils.rm_rf(global_bundler_d_dir)
      FileUtils.mv(global_bundler_d_backup_dir, global_bundler_d_dir)
    end

    attr_reader :out, :err, :process_status

    def bundler_version
      Helpers.bundler_version
    end

    def bundler_short_version
      Helpers.bundler_short_version
    end

    def app_dir
      @app_dir ||= Pathname.new(Dir.mktmpdir)
    end

    def rm_app_dir
      return unless @app_dir
      FileUtils.rm_rf(@app_dir)
      @app_dir = nil
    end

    def rm_global_bundler_d_dir
      FileUtils.rm_rf(Helpers.global_bundler_d_dir)
    end

    def with_path_based_gem(source_repo)
      Dir.mktmpdir do |path|
        path = Pathname.new(path)
        Dir.chdir(path) do
          out, status = Open3.capture2e("git clone --depth 1 #{source_repo} the_gem")
          raise "An error occured while cloning #{source_repo.inspect}...\n#{out}" unless status.exitstatus == 0
        end
        path = path.join("the_gem")

        yield path
      end
    end

    def write_gemfile(contents)
      contents = "#{coverage_prelude}\n\n#{contents}"
      File.write(app_dir.join("Gemfile"), contents)
    end

    def lockfile
      lock_name = Bundler.settings["bundler_inject.enable_pristine"] ? "Gemfile.lock.local" : "Gemfile.lock"
      file = app_dir.join(lock_name)
      Bundler::LockfileParser.new(file.read) if file.exist?
    end

    def lockfile_specs
      return unless (lf = lockfile)
      lf.specs.map { |s| [s.name, s.version.to_s] }
    end

    def raw_bundle(command, verbose: false, env: {})
      command = "bundle #{Helpers.bundler_cli_version} #{command} #{"--verbose" if verbose}".strip
      out, err, process_status = Helpers.with_unbundled_env do
        Open3.capture3(env, command, :chdir => app_dir)
      end
      return command, out, err, process_status
    end

    def bundle(command, expect_error: false, verbose: false, env: {})
      command, @out, @err, @process_status = raw_bundle(command, verbose: verbose, env: env)
      if expect_error
        expect(@process_status.exitstatus).to_not eq(0), "#{command.inspect} succeeded but was not expected to."
      else
        expect(@process_status.exitstatus).to eq(0), "#{command.inspect} failed with:\n#{bundler_output}"
      end
    end

    def bundler_output
      s = StringIO.new
      s.puts "== STDOUT ===============".light_magenta
      s.puts out unless out.empty?
      s.puts "== STDERR ===============".light_magenta
      s.puts err unless err.empty?
      s.puts "== STATUS ===============".light_magenta
      s.puts process_status
      s.puts "=========================".light_magenta
      s.string
    end

    def write_bundler_d_file(content, filename = "local_overrides.rb")
      Dir.chdir(app_dir) do
        FileUtils.mkdir_p("bundler.d")
        File.write("bundler.d/#{filename}", content)
      end
    end

    def write_global_bundler_d_file(content, filename = "global_overrides.rb")
      Dir.chdir(Dir.home) do
        FileUtils.mkdir_p(".bundler.d")
        File.write(".bundler.d/#{filename}", content)
      end
    end

    def extract_rack_version(path = nil)
      unless path
        _, path, _, _ = raw_bundle("show rack")
        path = Pathname.new(path.chomp)
      end
      path.expand_path.join("lib/rack/version.rb").read[/RELEASE += +([\"\'])([\d][\w\.]+)\1/, 2]
    end
  end
end
