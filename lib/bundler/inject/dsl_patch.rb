module Bundler
  module Inject
    module DslPatch
      def override_gem(name, *args)
        if dependencies.any?
          raise "Trying to override unknown gem #{name}" unless (dependency = dependencies.find { |d| d.name == name })

          removed_dependency = dependencies.delete(dependency)
          if removed_dependency.source.kind_of?(Bundler::Source::Git)
            @sources.send(:source_list_for, removed_dependency.source).delete_if do |other_source|
              removed_dependency.source == other_source
            end
          end

          calling_file = caller_locations.detect { |loc| !loc.path.include?("lib/bundler") }.path
          calling_dir  = File.dirname(calling_file)

          args.last[:path] = File.expand_path(args.last[:path], calling_dir) if args.last.kind_of?(Hash) && args.last[:path]
          gem(name, *args).tap do
            warn "** override_gem: #{name}, #{args.inspect}, caller: #{calling_file}" unless ENV["RAILS_ENV"] == "production"
          end
        end
      end

      def eval_gemfile(gemfile, contents = nil, nested = false)
        super(gemfile, contents)
        load_bundler_d(File.dirname(gemfile)) unless nested
      end

      def load_bundler_d(gemfile_dir)
        # Load other additional Gemfiles
        #   Developers can create a file ending in .rb under bundler.d/ to specify additional development dependencies
        Dir.glob(File.join(gemfile_dir, 'bundler.d/*.rb')).each { |f| eval_gemfile(File.expand_path(f, gemfile_dir, true)) }
      end
    end
  end
end
