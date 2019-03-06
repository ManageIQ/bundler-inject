require "bundler/inject/version"
require "bundler/inject/dsl_patch"

module Bundler
  module Inject
    class << self
      # Check if we should skip outputing warnings
      #
      # This can be set in two ways:
      #
      #   - Via bundler's Bundler::Settings
      #   - When RAILS_ENV=production is set
      #
      # To configure the setting, you can run:
      #
      #   bundle config bundler_inject.disable_warn_override_gem true
      #
      # OR use an environment variable
      #
      #   BUNDLE_BUNDLER_INJECT__DISABLE_WARN_OVERRIDE_GEM=true bundle ...
      #
      # If neither are set, it will check for ENV["RAILS_ENV"] is "production",
      # and will skip if it is, but the bundler variable is present (and even
      # set to "false") that will be favored.
      def skip_warnings?
        return @skip_warnings if defined?(@skip_warnings)

        bundler_setting = Bundler.settings["bundler_inject.disable_warn_override_gem"]

        if bundler_setting.nil?
          ENV["RAILS_ENV"] == "production"
        else
          bundler_setting
        end
      end
    end
  end
end

Bundler::Dsl.prepend(Bundler::Inject::DslPatch)
ObjectSpace.each_object(Bundler::Dsl) do |o|
  o.singleton_class.prepend(Bundler::Inject::DslPatch)
end
