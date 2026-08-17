# frozen_string_literal: true

require "json"

module Craigslist
  module API
    # The response wrapper every JSON Bulkpost endpoint returns.
    #
    #   {"apiVersion": 1, "data": {...}, "errors": [], "accountMessages": []}
    #
    # Note that +errors+ can be populated on an HTTP 200 — status alone is not
    # enough to tell whether a call worked.
    class Envelope
      # @return [Numeric, nil]
      attr_reader :api_version

      # @return [Hash, Array, nil] the useful payload
      attr_reader :data

      # @return [Array<Hash>] +{"code", "message"}+ entries
      attr_reader :errors

      # @return [Array<Hash>] +{"messageId", "message"}+ notices, which keep
      #   appearing until acknowledged via {Resources::Account#acknowledge}
      attr_reader :account_messages

      def initialize(api_version: nil, data: nil, errors: [], account_messages: [])
        @api_version = api_version
        @data = data
        @errors = Array(errors)
        @account_messages = Array(account_messages)
        freeze
      end

      # @param body [String] raw JSON response body
      # @return [Envelope]
      # @raise [ParseError] if the body is not JSON
      def self.parse(body)
        payload = JSON.parse(body.to_s)

        # A few error paths return a bare object rather than a full envelope.
        payload = {} unless payload.is_a?(Hash)

        new(
          api_version: payload["apiVersion"],
          data: payload["data"],
          errors: payload["errors"],
          account_messages: payload["accountMessages"]
        )
      rescue JSON::ParserError => e
        raise ParseError, "expected JSON from the Bulkpost API: #{e.message}"
      end

      # @return [Boolean]
      def error?
        !errors.empty?
      end

      # @return [String] errors joined into one human-readable line
      def error_message
        errors.map { |e| e["message"] }.compact.join("; ")
      end
    end
  end
end
