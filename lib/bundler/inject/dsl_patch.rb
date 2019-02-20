module Bundler
  module Inject
    module DslPatch
      def override_gem(name, *args)
        raise "Trying to override unknown gem #{name.inspect}" unless (dependency = dependencies.find { |d| d.name == name })

        removed_dependency = dependencies.delete(dependency)
        if removed_dependency.source.kind_of?(Bundler::Source::Git)
          @sources.send(:source_list_for, removed_dependency.source).delete_if do |other_source|
            removed_dependency.source == other_source
          end
        end

        calling_loc  = caller_locations.detect { |loc| !loc.path.include?("lib/bundler") }
        calling_file = "#{calling_loc.path}:#{calling_loc.lineno}"
        calling_dir  = File.dirname(calling_file)

        args.last[:path] = File.expand_path(args.last[:path], calling_dir) if args.last.kind_of?(Hash) && args.last[:path]
        gem(name, *args).tap do
          warn "** override_gem: #{name}, #{args.inspect}, caller: #{calling_file}" unless ENV["RAILS_ENV"] == "production"
        end
      end

      def to_definition(lockfile, unlock)
        calling_loc = caller_locations(1, 1).first
        if calling_loc.path.include?("bundler/dsl.rb") && calling_loc.base_label == "evaluate"
          load_bundler_d(File.join(Dir.home, ".bundler.d"))
          @gemfiles.reverse_each do |gemfile|
            load_bundler_d(File.join(File.dirname(gemfile), "bundler.d"))
          end
        end
        super
      end

      private

      def load_bundler_d(dir)
        Dir.glob(File.join(dir, '*.rb')).sort.each do |f|
          Bundler.ui.info "Injecting #{f}..."
          eval_gemfile(f)
        end
      end
    end
  end
end
