# frozen_string_literal: true

source "https://rubygems.org"

# Runtime dependencies are declared in craigslist-api.gemspec.
gemspec

# Development dependencies live here rather than in the gemspec so they can be
# grouped and are never resolved by consumers of the gem.
group :development, :test do
  gem "rake", "~> 13.0"
  gem "rspec", "~> 3.13"
  gem "standard", "~> 1.35"
  gem "webmock", "~> 3.23"
  gem "yard", "~> 0.9"
end
