require "tmpdir"
require "open3"

module Spec
  module Helpers
    def self.bundler_version
      return @bundler_version if defined?(@bundler_version)
      versions = `gem list bundler | grep bundler`.chomp.match(/\(([^)]+)\)/)[1].split(",").map(&:strip)
      @bundler_version = versions.detect { |v| v.include?(ENV["BUNDLER_VERSION"]) }
    end

    def self.bundler_cli_version
      v = bundler_version
      "_#{v}_" if v
    end

    def self.global_bundler_d_dir
      @global_bundler_d_dir ||= Pathname.new("~/.bundler.d").expand_path
    end

    def self.global_bundler_d_backup_dir
      @global_bundler_d_backup_dir ||= Pathname.new("~/.bundler.d.rspec_backup").expand_path
    end

    def self.backup_global_bundler_d
      FileUtils.rm_rf(global_bundler_d_backup_dir)
      FileUtils.mv(global_bundler_d_dir, global_bundler_d_backup_dir) if global_bundler_d_dir.exist?
    end

    def self.restore_global_bundler_d
      FileUtils.rm_rf(global_bundler_d_dir)
      FileUtils.mv(global_bundler_d_backup_dir, global_bundler_d_dir) if global_bundler_d_backup_dir.exist?
    end

    attr_reader :out, :err, :process_status

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

    def debug_output
      puts "== STDOUT ===============".light_magenta
      puts out unless out.empty?
      puts "== STDERR ===============".light_magenta
      puts err unless err.empty?
      puts "== STATUS ===============".light_magenta
      puts process_status
      puts "=========================".light_magenta
    end

    def write_gemfile(contents)
      File.write(app_dir.join("Gemfile"), contents)
    end

    def lockfile
      file = app_dir.join("Gemfile.lock")
      Bundler::LockfileParser.new(file.read) if file.exist?
    end

    def lockfile_specs
      return unless (lf = lockfile)
      lf.specs.map { |s| [s.name, s.version.to_s] }
    end

    def raw_bundle(command, verbose: true)
      command = "bundle #{Helpers.bundler_cli_version} #{command} #{"--verbose" if verbose}".strip
      out, err, process_status = Bundler.with_clean_env do
        Open3.capture3(command, :chdir => app_dir)
      end
      return command, out, err, process_status
    end

    def bundle(command, expect_error: false, verbose: true)
      command, @out, @err, @process_status = raw_bundle(command, verbose: verbose)
      if expect_error
        expect(@process_status.exitstatus).to_not eq(0), "#{command.inspect} succeeded but was not expected to."
      else
        expect(@process_status.exitstatus).to eq(0), "#{command.inspect} failed with:\n#{@err}"
      end
    end

    def update_gemfile(contents)
      write_gemfile(contents)
      bundle(:update)
    end

    def plugin_gemfile_content
      @bundler_inject_root ||= Pathname.new(__dir__).join("../..").expand_path

      <<~G
        plugin "bundler-inject", :git => #{@bundler_inject_root.to_s.inspect}, :ref => "HEAD"
        require File.join(Bundler::Plugin.index.load_paths("bundler-inject")[0], "bundler-inject") rescue nil
      G
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
        _, path, _, _ = raw_bundle("show rack", verbose: false)
        path = Pathname.new(path.chomp)
      end
      path.join("lib/rack.rb").read[/RELEASE += +([\"\'])([\d][\w\.]+)\1/, 2]
    end
  end
end
