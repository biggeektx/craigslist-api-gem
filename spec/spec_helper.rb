# frozen_string_literal: true

require "craigslist/api"
require "webmock/rspec"

# Nothing in this suite is allowed to reach the network. Bulk posting access is
# granted by craigslist case by case, so there are no credentials to record
# against; every expectation is built from the documented payloads instead.
WebMock.disable_net_connect!

Dir[File.expand_path("support/**/*.rb", __dir__)].sort.each { |file| require file }

RSpec.configure do |config|
  config.include ClientHelpers
  config.include FixtureHelpers

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.disable_monkey_patching!
  config.example_status_persistence_file_path = ".rspec_status"
  config.order = :random
  Kernel.srand config.seed
end
