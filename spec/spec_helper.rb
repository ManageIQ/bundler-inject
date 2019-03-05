if ENV['CI']
  require 'simplecov'
  SimpleCov.start
end

require "bundler/setup"
require "colorize"

require "bundler/inject"

Dir[File.join(__dir__, "support/**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.include Spec::Helpers

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:suite) do
    # For specs, we are using a git clone in order to get the plugin into the
    #   fake test app.  As such, if any code changes are not committed they will
    #   be ignored, which can lead to confusion during development.
    #
    # This test ensures that we commit the code before testing it.
    if `git status lib --porcelain`.length != 0
      raise "You cannot run specs with uncommitted changes to the lib directory."
    end

    puts
    puts "Using bundler #{Spec::Helpers.bundler_version}".light_yellow

    Spec::Helpers.backup_global_bundler_d
  end

  config.after(:suite) do
    Spec::Helpers.restore_global_bundler_d
  end

  config.after do
    rm_global_bundler_d_dir
    rm_app_dir
  end
end
