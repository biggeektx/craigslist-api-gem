# frozen_string_literal: true

module Craigslist
  module API
    # Submits postings to the RSS bulk interface.
    #
    # Validate and post take identical documents and differ only in the URL, so
    # validating is a genuine dry run of the exact payload that would be posted.
    class BulkTransport
      # The protocol section of the documentation asks for text/xml. The
      # changelog mentions application/xml and the sample client still sends
      # form encoding; text/xml is the one the protocol itself specifies.
      CONTENT_TYPE = "text/xml; charset=utf-8"

      # Dry-run endpoint. Takes the same document as {POST_PATH}.
      VALIDATE_PATH = "/bulk-rss/validate"

      # Endpoint that actually creates postings.
      POST_PATH = "/bulk-rss/post"

      def initialize(config:, connection:)
        @config = config
        @connection = connection
        @serializer = Serializer.new(config)
      end

      # Dry run: checks the document without creating anything.
      #
      # @param postings [Posting, Array<Posting>]
      # @return [ResultSet]
      def validate(postings)
        submit(VALIDATE_PATH, postings)
      end

      # Creates the postings.
      #
      # @param postings [Posting, Array<Posting>]
      # @return [ResultSet]
      def post(postings)
        submit(POST_PATH, postings)
      end

      private

      attr_reader :config, :connection, :serializer

      def submit(path, postings)
        list = Array(postings)
        raise ValidationError, ["at least one posting is required"] if list.empty?

        assert_unique_keys!(list)

        response = Connection.perform do
          connection.post(path) do |req|
            req.headers["Content-Type"] = CONTENT_TYPE
            req.headers["Accept"] = "text/xml"
            req.body = serializer.serialize(list)
          end
        end

        raise_for_status(response)
        ResponseParser.parse(response.body)
      end

      # Keys identify postings within the document and are how results are
      # matched back to submissions, so a collision would silently lose one.
      def assert_unique_keys!(postings)
        duplicates = postings.map(&:key).tally.select { |_, count| count > 1 }.keys
        return if duplicates.empty?

        raise ValidationError, ["duplicate posting keys: #{duplicates.inspect}"]
      end

      def raise_for_status(response)
        return if response.success?

        body = response.body.to_s
        message = "bulk submission failed with HTTP #{response.status}"
        message += ": #{body.strip}" unless body.strip.empty?

        error_class =
          case response.status
          when 403 then AuthenticationError
          when 400, 415 then RequestError
          when 429 then RateLimitError
          when 500..599 then ServerError
          else ResponseError
          end

        raise error_class.new(message, status: response.status, body: body)
      end
    end
  end
end
