# frozen_string_literal: true

# Loads the response fixtures, which are transcribed from craigslist's own
# published examples so the parser is tested against the real shape.
module FixtureHelpers
  FIXTURE_ROOT = File.expand_path("../fixtures", __dir__)

  def fixture(name)
    File.read(File.join(FIXTURE_ROOT, name))
  end
end
