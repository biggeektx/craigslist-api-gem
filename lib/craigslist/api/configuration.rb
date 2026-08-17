# frozen_string_literal: true

module Craigslist
  module API
    # Immutable configuration for a {Client}.
    #
    # Instances are frozen on construction. Nothing mutates configuration at
    # request time, which keeps a single client safe to share across threads.
    # Multi-account setups build one client per account rather than swapping
    # credentials on a global.
    class Configuration
      # Host serving the RSS bulk posting interface (posting creation).
      DEFAULT_BULK_HOST = "https://post.craigslist.org"

      # Host serving the JSON Bulkpost API (everything after creation).
      DEFAULT_BAPI_HOST = "https://bapi.craigslist.org"

      # Host serving public areas/categories reference data. No auth required.
      DEFAULT_REFERENCE_HOST = "https://reference.craigslist.org"

      # Top-level OAuth scopes. Scopes are hierarchical, so requesting
      # +bulkpost.posting+ also grants +bulkpost.posting.delete+ and friends.
      DEFAULT_SCOPES = %w[
        bulkpost.posting
        bulkpost.account.billing
        bulkpost.account.message
        bulkpost.account.stats
      ].freeze

      # Bulk submissions can carry base64 image payloads, so the default read
      # timeout is generous.
      DEFAULT_TIMEOUT = 120

      # Connection establishment timeout, in seconds.
      DEFAULT_OPEN_TIMEOUT = 15

      attr_reader :email, :password, :account_id, :scopes, :bulk_host, :bapi_host,
        :reference_host, :timeout, :open_timeout, :user_agent, :logger, :adapter

      # @param email [String] the craigslist account email used to log in
      # @param password [String] the craigslist account password
      # @param account_id [String, Integer] craigslist account number with
      #   posting credit, for which +email+ is an authorized buyer
      # @param scopes [Array<String>] OAuth scopes to request
      # @param bulk_host [String] override the RSS interface host
      # @param bapi_host [String] override the JSON API host
      # @param reference_host [String] override the reference data host
      # @param timeout [Integer] read timeout in seconds
      # @param open_timeout [Integer] connection timeout in seconds
      # @param user_agent [String] value sent as +User-Agent+
      # @param logger [Logger, nil] when set, Faraday logs requests to it
      # @param adapter [Symbol] Faraday adapter to use
      # @raise [ConfigurationError] if any credential is blank
      def initialize(
        email:,
        password:,
        account_id:,
        scopes: DEFAULT_SCOPES,
        bulk_host: DEFAULT_BULK_HOST,
        bapi_host: DEFAULT_BAPI_HOST,
        reference_host: DEFAULT_REFERENCE_HOST,
        timeout: DEFAULT_TIMEOUT,
        open_timeout: DEFAULT_OPEN_TIMEOUT,
        user_agent: "craigslist-api-ruby/#{VERSION}",
        logger: nil,
        adapter: Faraday.default_adapter
      )
        @email = presence!(email, :email)
        @password = presence!(password, :password)
        @account_id = presence!(account_id, :account_id).to_s
        @scopes = Array(scopes).map(&:to_s).freeze
        @bulk_host = bulk_host
        @bapi_host = bapi_host
        @reference_host = reference_host
        @timeout = timeout
        @open_timeout = open_timeout
        @user_agent = user_agent
        @logger = logger
        @adapter = adapter

        freeze
      end

      # The OAuth2 +client_id+, which Craigslist defines as the account email
      # and account id joined by a semicolon.
      #
      # @return [String]
      def client_id
        "#{email};#{account_id}"
      end

      # HTTP Basic credential for the token endpoint.
      #
      # Encoded with +Array#pack+ rather than the +base64+ gem, which stopped
      # being a default gem in Ruby 3.4 and would otherwise add a dependency.
      #
      # @return [String]
      def basic_authorization
        "Basic #{["#{client_id}:#{password}"].pack("m0")}"
      end

      # @return [String] the URL RSS submissions are validated against
      def validate_url
        "#{bulk_host}/bulk-rss/validate"
      end

      # @return [String] the URL RSS submissions are posted to
      def post_url
        "#{bulk_host}/bulk-rss/post"
      end

      # Redacts the password so credentials never leak into logs or exception
      # output through a stray +inspect+.
      #
      # @return [String]
      def inspect
        "#<#{self.class.name} email=#{email.inspect} account_id=#{account_id.inspect} password=[FILTERED]>"
      end
      alias_method :to_s, :inspect

      private

      def presence!(value, name)
        string = value.to_s.strip
        raise ConfigurationError, "#{name} is required" if string.empty?
        value.is_a?(String) ? string : value
      end
    end
  end
end
