# frozen_string_literal: true

require "faraday"
require "faraday/multipart"

module Craigslist
  module API
    # Builds the Faraday connections the client uses.
    #
    # Connections are built once per client and reused. The adapter is taken
    # from configuration so host applications can swap in their own (or a test
    # stub) without this gem forcing a choice on them.
    module Connection
      module_function

      # @param url [String] base URL for the connection
      # @param config [Configuration]
      # @param multipart [Boolean] enable the multipart request middleware
      # @return [Faraday::Connection]
      def build(url:, config:, multipart: false)
        Faraday.new(url: url) do |f|
          f.request :multipart if multipart

          f.headers["User-Agent"] = config.user_agent
          f.options.timeout = config.timeout
          f.options.open_timeout = config.open_timeout

          f.response :logger, config.logger, headers: false, bodies: false if config.logger

          f.adapter config.adapter
        end
      end

      # Runs a request, translating Faraday's transport exceptions into this
      # library's error hierarchy.
      #
      # Deliberately does not use Faraday's +:raise_error+ middleware. That
      # middleware keys purely on HTTP status, and neither Craigslist API treats
      # status as the source of truth — so status handling lives with the code
      # that also understands in-band failures.
      #
      # @yieldreturn [Faraday::Response]
      # @return [Faraday::Response]
      # @raise [TimeoutError, ConnectionError]
      def perform
        yield
      rescue Faraday::TimeoutError => e
        raise TimeoutError, "request timed out: #{e.message}"
      rescue Faraday::ConnectionFailed, Faraday::SSLError => e
        raise ConnectionError, "connection failed: #{e.message}"
      end
    end
  end
end
