require_relative "lib/sentry/sidekiq/version"

Gem::Specification.new do |spec|
  spec.name          = "sentry-sidekiq"
  spec.version       = Sentry::Sidekiq::VERSION
  spec.authors = ["Sentry Team"]
  spec.description = spec.summary = "A gem that provides Sidekiq integration for the Sentry error logger"
  spec.email = "accounts@sentry.io"
  spec.license = 'Apache-2.0'
  spec.homepage = "https://github.com/getsentry/sentry-ruby"

  spec.platform = Gem::Platform::RUBY
  spec.required_ruby_version = '>= 2.4'
  spec.extra_rdoc_files = ["README.md", "LICENSE.txt"]
  spec.files = `git ls-files | grep -Ev '^(spec|benchmarks|examples)'`.split("\n")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/master/sentry-sidekiq/CHANGELOG.md"

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "sentry-ruby-core", "~> 4.2.0"
end
