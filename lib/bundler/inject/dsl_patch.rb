module Bundler
  module Inject
    module DslPatch
      def override_gem(name, *args)
        raise "Trying to override unknown gem #{name}" unless (dependency = dependencies.find { |d| d.name == name })

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

      def eval_gemfile(gemfile, contents = nil, nested = false)
        super(gemfile, contents)
        return if nested
        load_bundler_d(File.dirname(gemfile))
        load_bundler_d(Dir.home)
      end

      private

      def load_bundler_d(dir)
        Dir.glob(File.join(dir, 'bundler.d/*.rb')).sort.each do |f|
          puts "Injecting #{f}..."
          eval_gemfile(f, nil, true)
        end
      end
    end
  end
end
