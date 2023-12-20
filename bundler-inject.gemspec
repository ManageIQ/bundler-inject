lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "bundler/inject/version"

Gem::Specification.new do |spec|
  spec.name          = "bundler-inject"
  spec.version       = Bundler::Inject::VERSION
  spec.authors       = ["ManageIQ Authors"]

  spec.summary       = %q{A bundler plugin that allows extension of a project with personal and overridden gems}
  spec.description   = %q{bundler-inject is a bundler plugin that allows a developer to extend a project with their own personal gems and/or override existing gems, without having to modify the Gemfile, thus avoiding accidental modification of git history.}
  spec.homepage      = "https://github.com/ManageIQ/bundler-inject"
  spec.license       = "Apache-2.0"

  if spec.respond_to?(:metadata=)
    spec.metadata = {
      "bug_tracker_uri" => "https://github.com/ManageIQ/bundler-inject/issues",
      "changelog_uri"   => "https://github.com/ManageIQ/bundler-inject/blob/master/CHANGELOG.md",
      "source_code_uri" => "https://github.com/ManageIQ/bundler-inject/",
    }
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "colorize"
  spec.add_development_dependency "manageiq-style"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec",     "~> 3.0"
  spec.add_development_dependency "simplecov", ">= 0.21.2"
end
