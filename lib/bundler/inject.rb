require "bundler/inject/version"
require "bundler/inject/dsl_patch"

Bundler::Dsl.prepend(Bundler::Inject::DslPatch)
