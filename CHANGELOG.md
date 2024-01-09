Version 2.0

# Bundler-inject Changelog

Doing our best at supporting [SemVer](http://semver.org/) with
a nice looking [Changelog](http://keepachangelog.com).

## Version [HEAD] <sub><sup>now</sub></sup>

## Version [2.1.0] <sub><sup>2024-01-09</sub></sup>

### Fixed
* Remove remnants of bundler 1.x support ([#20](https://github.com/ManageIQ/bundler-inject/pull/20))
* Fix detection of bundler version ([#21](https://github.com/ManageIQ/bundler-inject/pull/21))
* Fix spec issues after release of bundler 2.4.17 ([#32](https://github.com/ManageIQ/bundler-inject/pull/32))

### Added
* Switch to GitHub Actions ([#25](https://github.com/ManageIQ/bundler-inject/pull/25))
* Add bundler 2.4 to the test matrix ([#28](https://github.com/ManageIQ/bundler-inject/pull/28))
* Add Ruby 3.1 and 3.2 to test matrix ([#29](https://github.com/ManageIQ/bundler-inject/pull/29))
* Allow user to specify a PATH to search for gem overrides ([#34](https://github.com/ManageIQ/bundler-inject/pull/34))

## Version [2.0.0] <sub><sup>2021-05-01</sub></sup>

* **BREAKING**: Drops support for bundler below 2.0
* **BREAKING**: Drops support for Ruby below 2.6
* Adds support for running as a service (with no user / HOME set)

[HEAD]: https://github.com/ManageIQ/bundler-inject/compare/v2.1.0...HEAD
[2.1.0]: https://github.com/ManageIQ/bundler-inject/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/ManageIQ/bundler-inject/compare/v1.1.0...v2.0.0
