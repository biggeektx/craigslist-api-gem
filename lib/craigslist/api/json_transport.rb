# frozen_string_literal: true

require "uri"

module Craigslist
  module API
    # Request plumbing for the JSON Bulkpost API.
    #
    # Owns three concerns the resource classes should not repeat: attaching a
    # bearer token (refreshing once on a 401), mapping HTTP status onto this
    # library's error classes, and unwrapping the response envelope.
    class JsonTransport
      # Writes to the Bulkpost API are form-encoded, not JSON, even though the
      # responses are JSON.
      FORM_CONTENT_TYPE = "application/x-www-form-urlencoded"

      # @return [Array<Hash>] account notices seen on the most recent response
      attr_reader :account_messages

      def initialize(config:, connection:, token_provider:)
        @config = config
        @connection = connection
        @token_provider = token_provider
        @account_messages = []
      end

      # @return [Envelope]
      def get(path, params: {})
        run(:get, path, params: params)
      end

      # @return [Envelope]
      def post(path, form: nil)
        run(:post, path, form: form)
      end

      # @return [Envelope]
      def put(path, form: nil)
        run(:put, path, form: form)
      end

      # @return [Envelope]
      def delete(path)
        run(:delete, path)
      end

      # Uploads a file as +multipart/form-data+.
      #
      # @param path [String]
      # @param part [Faraday::Multipart::FilePart]
      # @param fields [Hash] additional form fields
      # @return [Envelope]
      def upload(path, part:, fields: {})
        run(:put, path, body: fields.merge("file" => part), content_type: nil)
      end

      private

      def run(method, path, params: {}, form: nil, body: nil, content_type: FORM_CONTENT_TYPE, retried: false)
        response = Connection.perform do
          @connection.public_send(method, path) do |req|
            req.headers["Authorization"] = @token_provider.token.to_header
            req.headers["Accept"] = "application/json"
            req.params.update(stringify(params)) unless params.empty?

            if form && !form.empty?
              req.headers["Content-Type"] = content_type if content_type
              req.body = URI.encode_www_form(form)
            elsif body
              req.body = body
            end
          end
        end

        # A 401 can precede the recorded expiry if the token was revoked, so
        # give it exactly one refresh-and-retry before surfacing the failure.
        if response.status == 401 && !retried
          @token_provider.invalidate!
          return run(method, path,
            params: params, form: form, body: body,
            content_type: content_type, retried: true)
        end

        handle(response)
      end

      def handle(response)
        envelope = safe_envelope(response)
        @account_messages = envelope&.account_messages || []

        raise_for_status(response, envelope) unless response.success?

        # HTTP 200 with a populated errors array is a real failure mode here.
        if envelope.error?
          raise APIError.new(
            envelope.error_message,
            status: response.status,
            body: response.body,
            api_errors: envelope.errors
          )
        end

        envelope
      end

      def safe_envelope(response)
        return nil if response.body.nil? || response.body.to_s.strip.empty?

        Envelope.parse(response.body)
      rescue ParseError
        # Error responses are not guaranteed to be JSON; let raise_for_status
        # report the status with the raw body instead.
        nil
      end

      def raise_for_status(response, envelope)
        message = envelope&.error?  ? envelope.error_message : "HTTP #{response.status}"
        attrs = {
          status: response.status,
          body: response.body,
          api_errors: envelope&.errors || []
        }

        raise error_class(response.status).new(message, **attrs)
      end

      def error_class(status)
        case status
        when 400 then RequestError
        when 401, 403 then AuthenticationError
        when 404 then NotFoundError
        when 429 then RateLimitError
        when 500..599 then ServerError
        else ResponseError
        end
      end

      def stringify(params)
        params.each_with_object({}) do |(key, value), memo|
          memo[key.to_s] = value unless value.nil?
        end
      end
    end
  end
end
