# frozen_string_literal: true

require "json"
require "uri"

module Craigslist
  module API
    # Acquires and caches the OAuth2 access token used by the JSON API.
    #
    # Tokens live an hour. This holds one per client instance, guarded by a
    # mutex so concurrent callers on a shared client cannot stampede the token
    # endpoint or read a half-replaced token. Deliberately an instance, not a
    # class-level cache: one process may talk to several accounts.
    class TokenProvider
      TOKEN_PATH = "/bulkpost/oauth/access-token"

      # @param config [Configuration]
      # @param connection [Faraday::Connection] pointed at the bapi host
      def initialize(config:, connection:)
        @config = config
        @connection = connection
        @mutex = Mutex.new
        @token = nil
      end

      # Returns a live token, fetching or refreshing if needed.
      #
      # @return [AccessToken]
      def token
        @mutex.synchronize do
          @token = fetch if @token.nil? || @token.expired?
          @token
        end
      end

      # Drops the cached token so the next call re-authenticates.
      #
      # Called after a 401, which can happen before the recorded expiry if the
      # token was revoked server-side.
      #
      # @return [void]
      def invalidate!
        @mutex.synchronize { @token = nil }
      end

      private

      def fetch
        response = Connection.perform do
          @connection.post(TOKEN_PATH) do |req|
            req.headers["Authorization"] = @config.basic_authorization
            req.headers["Content-Type"] = "application/x-www-form-urlencoded"
            req.headers["Accept"] = "application/json"
            req.body = URI.encode_www_form(
              grant_type: "client_credentials",
              scope: @config.scopes.join(" ")
            )
          end
        end

        unless response.success?
          raise AuthenticationError.new(
            "token request failed with HTTP #{response.status}",
            status: response.status,
            body: response.body
          )
        end

        AccessToken.from_payload(parse(response))
      end

      def parse(response)
        JSON.parse(response.body.to_s)
      rescue JSON::ParserError => e
        raise ParseError, "token endpoint returned invalid JSON: #{e.message}"
      end
    end
  end
end
