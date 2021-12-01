module Bundler
  module Inject
    module DslPatch
      def override_gem(name, *args)
        raise "Trying to override unknown gem #{name.inspect}" unless (dependency = find_dependency(name.to_s))

        calling_loc  = caller_locations.detect { |loc| !loc.path.include?("lib/bundler") }
        calling_file = "#{calling_loc.path}:#{calling_loc.lineno}"

        remove_dependencies_and_sources(dependency)
        expand_gem_path(args, calling_file)
        gem(name, *args).tap do
          warn_override_gem(calling_file, name, args)
        end
      end

      def ensure_gem(name, *args)
        current = find_dependency(name)
        if !current
          gem(name, *args)
        else
          version, opts = extract_version_opts(args)
          version = [">= 0"] if version.empty?
          if opts.any? || (version != [">= 0"] && Gem::Requirement.new(version) != current.requirement)
            override_gem(name, *args)
          end
        end
      end

      def to_definition(lockfile, unlock)
        return super if ENV['BUNDLER_INJECT__DISABLE_OVERRIDE']

        original_unlock = unlock.dup
        original_lockfile = lockfile
        lockfile = Pathname.new("#{lockfile}.local") if enable_pristine?(lockfile)

        calling_loc = caller_locations(1, 1).first
        if calling_loc.path.include?("bundler/dsl.rb") && calling_loc.base_label == "evaluate"
          load_global_bundler_d

          # @gemfiles doesn't exist on Bundler <= 1.15, and we can't get at @gemfile
          #   by this point, but there's a high probability it's just "Gemfile",
          #   or slightly more accurately, the lockfile name without the ".lock" bit.
          targets = defined?(@gemfiles) ? @gemfiles : [Pathname.new(original_lockfile.to_s.chomp(".lock"))]

          targets.reverse_each do |gemfile|
            load_local_bundler_d(File.dirname(gemfile))
          end
        end

        super(lockfile, unlock).tap do |definition|
          add_pristine_lock(definition, original_unlock) if enable_pristine?(original_lockfile)
        end
      end

      private

      def find_dependency(name)
        dependencies.find { |d| d.name == name }
      end

      def remove_dependencies_and_sources(dependency)
        removed_dependency = dependencies.delete(dependency)
        if removed_dependency.source.kind_of?(Bundler::Source::Git)
          @sources.send(:source_list_for, removed_dependency.source).delete_if do |other_source|
            removed_dependency.source == other_source
          end
        end
      end

      def expand_gem_path(args, calling_file)
        return unless args.last.kind_of?(Hash) && args.last[:path]
        args.last[:path] = File.expand_path(args.last[:path], File.dirname(calling_file))
      end

      def extract_version_opts(args)
        args.last.is_a?(Hash) ? [args[0..-2], args[-1]] : [args, {}]
      end

      def warn_override_gem(calling_file, name, args)
        return if Bundler::Inject.skip_warnings?

        version, opts = extract_version_opts(args)
        message = "** override_gem(#{name.inspect}"
        message << ", #{version.inspect[1..-2]}" unless version.empty?
        message << ", #{opts.inspect[1..-2]}" unless opts.empty?
        message << ") at #{calling_file}"
        message = "\e[33m#{message}\e[0m" if $stdout.tty?

        warn message
      end

      def load_global_bundler_d
        if ENV["HOME"]
          load_bundler_d(File.join(Dir.home, ".bundler.d"))
        end
      end

      def load_local_bundler_d(dir)
        load_bundler_d(File.join(dir, "bundler.d"))
      end

      def load_bundler_d(dir)
        Dir.glob(File.join(dir, '*.rb')).sort.each do |f|
          Bundler.ui.debug "Injecting #{f}..."
          eval_gemfile(f)
        end
      end

      def add_pristine_lock(definition, original_unlock)
        definition.define_singleton_method(:lock) do |file, *args|
          original_disable = ENV['BUNDLER_INJECT__DISABLE_OVERRIDE']
          ENV['BUNDLER_INJECT__DISABLE_OVERRIDE'] = 'true'

          pristine_definition = Bundler::Dsl.evaluate(@gemfiles.first, Bundler.default_lockfile, original_unlock)
          pristine_definition.resolve_remotely! if pristine_definition.missing_specs?
          pristine_definition.lock(Bundler.default_lockfile, *args)

          ENV['BUNDLER_INJECT__DISABLE_OVERRIDE'] = original_disable
          super(Pathname.new("#{file}.local"), *args)
        end
      end

      def enable_pristine?(lockfile)
        lockfile == Bundler.default_lockfile && Bundler.settings["bundler_inject.enable_pristine"]
      end
    end
  end
end
