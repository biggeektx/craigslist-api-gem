# frozen_string_literal: true

module Craigslist
  module API
    # The single entry point for both halves of the Craigslist bulk posting
    # platform.
    #
    # Craigslist splits the work across two services with different formats and
    # different authentication: postings are *created* through an RSS interface
    # authenticated with credentials embedded in the XML, and *managed*
    # afterwards through a JSON API authenticated with an OAuth2 bearer token.
    # One set of credentials covers both. This client owns that seam so callers
    # do not have to think about it — {#post} and {#posting} are the same
    # object's methods, and the token lifecycle is invisible.
    #
    # Configuration is frozen and nothing mutates at request time, so a client
    # is safe to share across threads. Talking to several accounts means
    # building several clients, which is deliberate: there is no global to
    # reconfigure and no ambient state to get wrong.
    #
    # @example Creating postings
    #   client = Craigslist::API::Client.new(
    #     email: "you@example.com",
    #     password: ENV.fetch("CRAIGSLIST_PASSWORD"),
    #     account_id: 1234
    #   )
    #
    #   posting = Craigslist::API::Posting.new(
    #     key: "listing-1",
    #     title: "1998 Toyota Hilux",
    #     description: "Runs great.",
    #     category: "ctd",
    #     area: "sfo",
    #     price: 4500,
    #     reply_email: "sales@example.com",
    #     location: {postal: "94110"}
    #   )
    #
    #   results = client.validate(posting)   # dry run
    #   results = client.post(posting) if results.all_successful?
    #
    # @example Managing what you created
    #   live = client.posting(results.posting_ids.first)
    #   live.price = 4200
    #   live.add_image("front.jpg")
    class Client
      # @return [Configuration]
      attr_reader :config

      # @param email [String] craigslist account email
      # @param password [String] craigslist account password
      # @param account_id [String, Integer] craigslist account number
      # @param options [Hash] any other {Configuration} keyword
      # @raise [ConfigurationError] when credentials are missing
      def initialize(email:, password:, account_id:, **options)
        @config = Configuration.new(
          email: email,
          password: password,
          account_id: account_id,
          **options
        )

        build_components
      end

      # Builds a client from an existing {Configuration}.
      #
      # @param config [Configuration]
      # @return [Client]
      def self.from_config(config)
        allocate.tap do |client|
          client.instance_variable_set(:@config, config)
          client.send(:build_components)
        end
      end

      # Checks postings without creating anything.
      #
      # Sends the identical document {#post} would, so a clean validation is a
      # real rehearsal rather than an approximation.
      #
      # @param postings [Posting, Array<Posting>]
      # @return [ResultSet]
      # @raise [ValidationError] if no postings were given, or keys collide
      def validate(postings)
        bulk.validate(postings)
      end

      # Creates postings.
      #
      # Does not raise when individual postings fail — a batch with some
      # rejections is ordinary. Inspect the returned {ResultSet}.
      #
      # @param postings [Posting, Array<Posting>]
      # @return [ResultSet]
      def post(postings)
        bulk.post(postings)
      end

      # A handle for working with one live posting.
      #
      # @param posting_id [String, Integer]
      # @return [PostingHandle]
      def posting(posting_id)
        PostingHandle.new(self, posting_id)
      end

      # @return [Resources::Postings]
      attr_reader :postings

      # @return [Resources::Images]
      attr_reader :images

      # @return [Resources::Billing]
      attr_reader :billing

      # @return [Resources::Account]
      attr_reader :account

      # @return [Reference] public areas and categories data
      attr_reader :reference

      # @return [CreditSummary]
      def credit
        billing.credit
      end

      # @return [Array<PostingBlock>]
      def posting_blocks
        billing.posting_blocks
      end

      # @param area [String]
      # @param category [String]
      # @return [Money, nil]
      def pricing(area:, category:)
        billing.pricing(area: area, category: category)
      end

      # @param zip [String]
      # @return [Hash{Symbol => String}]
      def area_for_zip(zip)
        postings.area_for_zip(zip)
      end

      # @see Resources::Account#stats
      # @return [Array<PostingStats>]
      def stats(start: nil, stop: nil)
        account.stats(start: start, stop: stop)
      end

      # Notices attached to the most recent JSON API response.
      #
      # Craigslist repeats these on every response until acknowledged, so it is
      # worth surfacing them somewhere a human will look.
      #
      # @return [Array<Hash>] +{"messageId", "message"}+ entries
      def account_messages
        @json_transport.account_messages
      end

      # Discards the cached OAuth token, forcing the next JSON call to
      # re-authenticate. Rarely needed; the token refreshes itself.
      #
      # @return [void]
      def reset_token!
        @token_provider.invalidate!
      end

      def inspect
        "#<#{self.class.name} email=#{config.email.inspect} account_id=#{config.account_id.inspect}>"
      end
      alias_method :to_s, :inspect

      private

      # Built eagerly rather than memoized: connections are cheap, and lazy
      # construction would race two threads into two token providers.
      def build_components
        bapi_connection = Connection.build(url: config.bapi_host, config: config)

        @token_provider = TokenProvider.new(config: config, connection: bapi_connection)

        @json_transport = JsonTransport.new(
          config: config,
          connection: Connection.build(url: config.bapi_host, config: config, multipart: true),
          token_provider: @token_provider
        )

        @bulk = BulkTransport.new(
          config: config,
          connection: Connection.build(url: config.bulk_host, config: config)
        )

        @postings = Resources::Postings.new(@json_transport)
        @images = Resources::Images.new(@json_transport)
        @billing = Resources::Billing.new(@json_transport)
        @account = Resources::Account.new(@json_transport)
        @reference = Reference.new(
          Connection.build(url: config.reference_host, config: config)
        )
      end

      attr_reader :bulk
    end
  end
end
