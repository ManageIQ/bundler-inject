#
# Custom Gemfile modifications
#

# Load developer specific Gemfile
#   Developers can create a file called Gemfile.dev.rb containing any gems for
#   their local development.  This can be any gem under evaluation that other
#   developers may not need or may not easily install, such as rails-dev-boost,
#   any git based gem, and compiled gems like rbtrace or memprof.
if File.exist?(File.expand_path("Gemfile.dev.rb", File.dirname(__FILE__)))
  MiqBundler.include_gemfile("Gemfile.dev.rb", binding)
end

# Load plugins that are packaged as Gems
Dir["#{File.dirname(__FILE__)}/bundler.d/*.rb"].each do |bundle|
  MiqBundler.include_gemfile(bundle, binding)
end
