require "bundler/inject/version"
require "bundler/inject/dsl_patch"

Bundler::Dsl.prepend(Bundler::Inject::DslPatch)
ObjectSpace.each_object(Bundler::Dsl) do |o|
  o.singleton_class.prepend(Bundler::Inject::DslPatch)
end
