# bundler-inject

[![Build Status](https://travis-ci.org/ManageIQ/bundler-inject.svg?branch=master)](https://travis-ci.org/ManageIQ/bundler-inject)
[![Maintainability](https://api.codeclimate.com/v1/badges/e4650d6dd7cbcd981057/maintainability)](https://codeclimate.com/github/ManageIQ/bundler-inject/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/e4650d6dd7cbcd981057/test_coverage)](https://codeclimate.com/github/ManageIQ/bundler-inject/test_coverage)

**bundler-inject** is a [bundler plugin](https://bundler.io/guides/bundler_plugins.html)
that allows a developer to extend a project with their own personal gems and/or
override existing gems, without having to modify the Gemfile, thus avoiding
accidental modification of git history.

## Installation

Add these lines to your application's `Gemfile`:

```ruby
plugin 'bundler-inject'
require File.join(Bundler::Plugin.index.load_paths("bundler-inject")[0], "bundler-inject") rescue nil
```

Additionally, commit a `bundler.d/.gitkeep` file, and add `/bundler.d` to your
`.gitignore` file. This will be one of the locations developers can place their
overrides.

## Usage

Once the above lines are in the Gemfile, subsequent bundle commands will attempt
to evaluate extra gemfiles from two locations if they are present.

- global - `~/.bundler.d/*.rb`
- project - `$PROJECT_DIR/bundler.d/*.rb`

For example, a developer may prefer the `pry` gem over `irb`, but can't use it
because the project Gemfile doesn't have `pry` in it. Instead of modifying the
Gemfile and hoping they don't commit the changes, they can create a
`bundler.d/developer.rb` file with the contents set to `gem "pry"`. From then on
the developer can use `pry`, even though the project didn't state it explicitly.

Since this example developer likely *always* wants to use `pry`, it would be
preferable to specify this as a global choice in a `~/.bundler.d/developer.rb`
file instead.

### override_gem

`override_gem` is an extra DSL command that allows overriding existing gems from
the Gemfile. A useful example of this is if you are making a change to a
dependent gem, and temporarily want to override the existing `gem` definition
with, a git or path reference.

For example, there is a project with a Gemfile with `gem "foo"` in it. We want
to fix a bug in foo, and we intend to make a pull request to upstream, but in
the interim we want to test our foo change with the project. Instead of
modifying the Gemfile and hoping we don't commit the changes, we can create a
`bundler.d/developer.rb` with the contents set to
`override_gem "foo", :git => "https://github.com/me/foo.git"`. bundler-inject
will output a warning to the screen to make us aware we are overriding, and
then it will use the new definition.

`override_gem` will raise an exception if the specified gem does not exist in
the original Gemfile.

### ensure_gem

`ensure_gem` is an extra DSL command similar to `override_gem`, and primarily
meant for the global override file.

One issue with the global file is that it specifies a new gem with `gem`, but
that gem already exists in the project you will get a nasty warning. Conversely,
if it specifies an override with `override_gem`, but the gem does not exist in
the project you will get an exception. To deal with these issues, you can use
`ensure_gem` in your global file.

`ensure_gem` works by checking if the gem is already in the dependency list, and
comparing the options specified. If the dependency does not exist, it uses `gem`,
otherwise if the options or version specified are significantly different, it
will use `override_gem`, otherwise it will just do nothing, deferring to the
original declaration.

## Configuration

To disable warnings that are output to the console when `override_gem` or
`ensure_gem` is in use, you can update a bundler setting:

```console
$ bundle config bundler_inject.disable_warn_override_gem true
```

or use an environment variable:

```console
$ export BUNDLE_BUNDLER_INJECT__DISABLE_WARN_OVERRIDE_GEM=true
```

There is a fallback for those that will check the `RAILS_ENV` environment
variable, and will disable the warning when in `"production"`.

## What is this sorcery?

While this is technically a bundler plugin, bundler-inject does not use the
expected plugin hooks/sources/commands. To understand how this works and why
these were not used, it's useful to understand how bundler passes over your
Gemfile.

For `bundle install`/`bundle update`, bundler makes two passes over the Gemfile.

On the first pass, bundler executes your Gemfile in a `Bundler::Plugin::DSL`
context. This class is a special subclass of `Bundler::Dsl`, where nearly all of
the usual DSL methods like `gem` and `gemspec` are a no-op, and the `plugin` DSL
method does it's thing. So, after the first pass, bundler sees only your plugin
gems, and will then install them into `.bundle/plugin`.

On the second pass, bundler executes your Gemfile in a `Bundler::Dsl` context,
where the usual DSL methods like `gem` and `gemspec` do their thing, and the
`plugin` DSL method is instead a no-op. This is the pass most people think of.

On the very first install of the plugin, between the two passes, bundler will
load your plugin to see what kind of features it has, whether hooks, sources, or
commands, and will store this information in the `.bundle/plugin/index` file.
It would seem that since the plugin code is loaded this would be an opportune
time to do what we need, but unfortunately this only happens on initial install.
On subsequent `bundle update` calls, bundler sees that the index file exists,
and doesn't need to load the plugin, since all of the information is in the
index.

Complicating the matter further, for `bundle check`/`bundle exec`, bundler makes
only one pass over the Gemfile in a `Bundler::Dsl` context.

One immediate question on your mind may be, why not just define a fake hook or
source, and then put the code in there. Unfortunately, the problem is that any
of hooks, sources, or commands that will trigger the load of the plugin occur
after the Gemfile has already been passed over, preventing us from adding to the
DSL, as well as loading extra gemfiles.

As such, the earliest we can possibly trigger our plugin load in all cases is
immediately after we declare the plugin in the Gemfile. This is why we need that
magic line after the plugin line in the Gemfile.

Once we have the ability to trigger a load of our plugin, whether direct via the
magic line, or automatically on first plugin installation, then the plugin can
manipulate the Bundler::Dsl to add the `override_gem` method and trigger the
eval of extra gemfiles.

## Development

Development of bundler plugins can be a little strange, with a few gotchas.

1. bundler installs your gem into the .bundle/plugin directory of the target
   project.
2. `plugin "bundler-inject", :path => "/path/to/bundler-inject"` doesn't work
   as expected since bundler needs to "install" your gem into .bundle/plugin,
   and thus doesn't know how. To get around this, use
   `:git => File.expand_path("/path/to/bundler-inject")`.
3. If you are using :git (which also applies to :path with the workaround
   above), bundler will only consider committed code. Therefore, you *must*
   commit your code in a temporary commit if you want it to be picked up.
4. bundler plugins are copied to .bundle/plugin only on first install, and then
   updated only if a change is detected. Unless you have a `:ref` or a changing
   version number, bundler will think your gem hasn't changed and will not
   update it, even if you commit something. To force bundler to pull in your
   changes, you will have to `rm -rf .bundle/plugin`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ManageIQ/bundler-inject.

## License

This project is available as open source under the terms of the [Apache License 2.0](http://www.apache.org/licenses/LICENSE-2.0).
