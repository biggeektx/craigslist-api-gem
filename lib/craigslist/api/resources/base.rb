# frozen_string_literal: true

module Craigslist
  module API
    # Endpoint groups for the JSON Bulkpost API, reached through {Client}.
    module Resources
      # Shared plumbing for the JSON API resource groups.
      class Base
        # Every JSON endpoint hangs off this prefix.
        BASE_PATH = "/bulkpost/v1"

        # Characters RFC 3986 leaves unreserved in a path segment.
        RESERVED = /[^A-Za-z0-9\-._~]/

        def initialize(transport)
          @transport = transport
        end

        private

        attr_reader :transport

        # Joins path segments, percent-encoding each one.
        #
        # Encoding matters here: image ids look like "4:00101_b1ztTgNtBAU" and
        # the colon would otherwise land in the path unescaped.
        #
        # @return [String]
        def path(*segments)
          [BASE_PATH, *segments.map { |segment| escape(segment) }].join("/")
        end

        def escape(segment)
          segment.to_s.b.gsub(RESERVED) { |char| format("%%%02X", char.ord) }
        end

        # Most endpoints wrap a single scalar in +data+; this pulls it out.
        def fetch(envelope, key)
          data = envelope.data
          data.is_a?(Hash) ? data[key] : nil
        end
      end
    end
  end
end
