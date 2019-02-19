require "bundler/inject/version"

module Bundler
  module Inject
    def inject!(dependencies)
      # get a new Bundler::Dsl instance
      builder = Bundler::Dsl.new

      # Set the dependencies to the dependencies from the existing definition
      builder.dependencies = dependencies

      # Set the rest of the instance variables from Bundler.definition
      #
      # Based on Ruby's pass-by-reference design, we should be fine mutating
      # these in the new Builder, and it should be reflected in the
      # Bundler.definition in the end... hopefully...
      #
      # TODO:  Specs so we test this across bundler versions!
      #
      # (best we can do with the limited flexibility of Bundler::Plugin)
      sources         = Bundler.definition.send(:sources)
      gemfiles        = Bundler.definition.gemfiles
      ruby_version    = Bundler.definition.send(:ruby_version)
      optional_groups = Bundler.definition.instance_variable_get(:@optional_groups)

      builder.instance_variable_set(:@sources,         sources)
      builder.instance_variable_set(:@gemfiles,        gemfiles)
      builder.instance_variable_set(:@ruby_version,    ruby_version)
      builder.instance_variable_set(:@optional_groups, optional_groups)

      # Load the global and local bundler.d dirs
      load_bundler_d(builder, global_bundler_d)
      load_bundler_d(builder, local_bundler_d)
    end
    module_function :inject!

    def load_bundler_d(builder, dir)
      Dir.glob(File.join(dir, '*.rb')).sort.each do |f|
        puts "Injecting #{f}..."
        builder.eval_gemfile(f, nil)
      end
    end
    module_function :load_bundler_d
    private_class_method :load_bundler_d

    def global_bundler_d
      File.join(Dir.home, ".bundler.d")
    end
    module_function :global_bundler_d
    private_class_method :global_bundler_d

    def local_bundler_d
      File.join(File.dirname(ENV["BUNDLE_GEMFILE"]), "bundler.d")
    end
    module_function :local_bundler_d
    private_class_method :local_bundler_d
  end
end

Bundler::Plugin.add_hook('before-install-all') do |dependencies|
  require "bundler/inject/dsl_patch"

  Bundler::Dsl.prepend(Bundler::Inject::DslPatch)
  Bundler::Inject.inject! dependencies
end
