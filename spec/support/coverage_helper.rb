module Spec
  module CoverageHelper
    GEM_ROOT = Pathname.new(__dir__).join("../..").expand_path

    class << self
      # NOTE: coverage_counter is not thread-safe for parallel tests
      attr_accessor :coverage_counter
    end
    self.coverage_counter = 0

    def self.fix_coverage_resultset_paths
      file = GEM_ROOT.join("coverage/.resultset.json")
      contents = File.read(file)
      contents.gsub!(%r{(?<=").+/\.bundle/plugin/bundler/gems/bundler-inject-\h+}, GEM_ROOT.to_s)
      File.write(file, contents)
    end

    def self.dependency_paths(gem_name)
      spec = Gem.loaded_specs[gem_name]
      deps = spec.dependencies.flat_map { |d| dependency_paths(d.name) }
      deps.unshift(File.join(spec.full_gem_path, "lib"))
    end

    def self.simplecov_dependency_paths
      @simplecov_dependency_paths ||= dependency_paths("simplecov")
    end

    def coverage_prelude
      <<~C.chomp
        if ENV['CI']
          $LOAD_PATH.concat(#{CoverageHelper.simplecov_dependency_paths.inspect})
          require 'simplecov'
          SimpleCov.root #{GEM_ROOT.to_s.inspect}
          SimpleCov.command_name "bundler-inject-#{CoverageHelper.coverage_counter += 1}"
          SimpleCov.formatter SimpleCov::Formatter::SimpleFormatter
          SimpleCov.start do
            filters.clear
            add_filter { |src| !src.filename.include?("/.bundle/plugin/") }
          end
        end
      C
    end
  end
end
