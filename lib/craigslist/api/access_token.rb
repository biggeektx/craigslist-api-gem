# frozen_string_literal: true

module Craigslist
  module API
    # An OAuth2 bearer token with an expiry.
    #
    # Immutable. {TokenProvider} discards and re-fetches rather than mutating.
    class AccessToken
      # Treat a token as expired this many seconds early, so a token does not
      # die in flight between the expiry check and the server receiving it.
      LEEWAY = 60

      # @return [String] the raw token value
      attr_reader :value

      # @return [Time] the moment the token stops being valid
      attr_reader :expires_at

      # @return [Array<String>] scopes the token was granted
      attr_reader :scopes

      # @return [String] usually "Bearer"
      attr_reader :token_type

      def initialize(value:, expires_in:, scopes: [], token_type: "Bearer", now: Time.now)
        @value = value
        @expires_at = now + expires_in.to_i
        @scopes = Array(scopes).flat_map { |s| s.to_s.split(/\s+/) }.freeze
        @token_type = token_type || "Bearer"
        freeze
      end

      # Builds a token from the token endpoint's JSON payload.
      #
      # @param payload [Hash]
      # @return [AccessToken]
      # @raise [AuthenticationError] if the payload carries no token
      def self.from_payload(payload, now: Time.now)
        value = payload["access_token"]
        raise AuthenticationError, "token endpoint returned no access_token" if value.nil? || value.empty?

        new(
          value: value,
          expires_in: payload.fetch("expires_in", 3600),
          scopes: payload["scopes"] || payload["scope"] || [],
          token_type: payload["token_type"],
          now: now
        )
      end

      # @return [Boolean] whether the token is expired, or close enough to it
      def expired?(now: Time.now)
        now >= (expires_at - LEEWAY)
      end

      # @return [String] value for the +Authorization+ header
      def to_header
        "#{token_type} #{value}"
      end

      # Keeps the token value out of logs and exception output.
      def inspect
        "#<#{self.class.name} token=[FILTERED] expires_at=#{expires_at.iso8601} scopes=#{scopes.inspect}>"
      end
      alias_method :to_s, :inspect
    end
  end
end
