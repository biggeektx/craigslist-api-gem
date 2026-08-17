# frozen_string_literal: true

module Craigslist
  module API
    # Base class for every error raised by this library. Rescuing this catches
    # anything the gem raises on purpose.
    class Error < StandardError; end

    # Raised when the client is constructed with missing or nonsensical
    # credentials or options.
    class ConfigurationError < Error; end

    # Raised when a {Posting} is missing fields the interface requires, caught
    # locally before a request is made.
    class ValidationError < Error
      # @return [Array<String>] every problem found, not just the first
      attr_reader :errors

      def initialize(errors)
        @errors = Array(errors)
        super(@errors.join("; "))
      end
    end

    # Raised when a request never produced a usable HTTP response: DNS failure,
    # connection refused, TLS problems, timeouts.
    class ConnectionError < Error; end

    # Raised when a request exceeded the configured timeout.
    class TimeoutError < ConnectionError; end

    # Raised when a response arrived but could not be parsed as the XML or JSON
    # the endpoint promised.
    class ParseError < Error; end

    # Raised when Craigslist returned a response we understand as a failure.
    #
    # Carries the HTTP status and raw body so callers can inspect what actually
    # came back, plus any structured errors extracted from a JSON envelope.
    class ResponseError < Error
      # @return [Integer, nil] HTTP status code
      attr_reader :status

      # @return [String, nil] raw response body
      attr_reader :body

      # @return [Array<Hash>] structured +{code:, message:}+ entries, when present
      attr_reader :api_errors

      def initialize(message = nil, status: nil, body: nil, api_errors: [])
        @status = status
        @body = body
        @api_errors = api_errors
        super(message)
      end
    end

    # Raised for malformed requests. The RSS interface uses HTTP 415 for RSS it
    # cannot parse; the JSON API uses 400.
    class RequestError < ResponseError; end

    # Raised when credentials were rejected, or the account is not authorized
    # for bulk posting. Covers HTTP 401 and 403, and OAuth token failures.
    class AuthenticationError < ResponseError; end

    # Raised on HTTP 404.
    class NotFoundError < ResponseError; end

    # Raised on HTTP 429.
    class RateLimitError < ResponseError; end

    # Raised on any 5xx.
    class ServerError < ResponseError; end

    # Raised when a JSON response arrived with HTTP 200 but carried a non-empty
    # +errors+ array in its envelope.
    #
    # This is separate from {ResponseError} subclasses keyed to status codes
    # because the Bulkpost API reports application-level failures in-band.
    class APIError < ResponseError; end
  end
end
