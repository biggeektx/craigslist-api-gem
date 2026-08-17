# frozen_string_literal: true

require_relative "lib/craigslist/api/version"

Gem::Specification.new do |spec|
  spec.name = "craigslist-api"
  spec.version = Craigslist::API::VERSION
  spec.authors = ["Nick Chewning"]
  spec.email = ["nchewning@gmail.com"]

  spec.summary = "Ruby client for the Craigslist bulk posting APIs"
  spec.description = <<~DESC.strip
    A single-client Ruby wrapper around both halves of Craigslist's bulk posting
    platform: the RSS bulk interface used to create postings, and the JSON
    Bulkpost API used to manage them afterwards. Handles OAuth2 token lifecycle,
    XML serialization, and per-posting result reporting behind one object.
  DESC
  spec.homepage = "https://github.com/biggeektx/craigslist-api-gem"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    # Pinned to the released tag so the link matches the gem you installed.
    "source_code_uri" => "#{spec.homepage}/tree/v#{spec.version}",
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "#{spec.homepage}/issues",
    "documentation_uri" => "https://rubydoc.info/gems/craigslist-api/#{spec.version}",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      f == File.basename(__FILE__) ||
        f.start_with?("spec/", ".git", ".standard", "Rakefile", "Gemfile", ".rspec")
    end
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", "~> 2.9"
  spec.add_dependency "faraday-multipart", "~> 1.0"
  spec.add_dependency "rexml", "~> 3.4"
end
