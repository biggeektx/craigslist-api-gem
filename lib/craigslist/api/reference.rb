# frozen_string_literal: true

require "json"

module Craigslist
  module API
    # Areas and categories, from craigslist's public reference service.
    #
    # These endpoints need no authentication and return bare JSON arrays rather
    # than the Bulkpost envelope, so they bypass {JsonTransport} entirely.
    #
    # Both payloads are static enough to fetch once and hold — areas is around
    # 165KB — so results are memoized per client behind a mutex.
    class Reference
      AREAS_PATH = "/Areas"
      CATEGORIES_PATH = "/Categories"

      def initialize(connection)
        @connection = connection
        @mutex = Mutex.new
        @areas = nil
        @categories = nil
      end

      # @return [Array<Area>]
      def areas
        @mutex.synchronize do
          @areas ||= get(AREAS_PATH).map { |entry| Area.from(entry) }.freeze
        end
      end

      # @return [Array<Category>]
      def categories
        @mutex.synchronize do
          @categories ||= get(CATEGORIES_PATH).map { |entry| Category.from(entry) }.freeze
        end
      end

      # @param abbreviation [String] e.g. "sfo"
      # @return [Area, nil]
      def area(abbreviation)
        areas.find { |a| a.abbreviation == abbreviation.to_s }
      end

      # @param abbreviation [String] e.g. "ctd"
      # @return [Category, nil]
      def category(abbreviation)
        categories.find { |c| c.abbreviation == abbreviation.to_s }
      end

      # Drops the cached payloads so the next call refetches.
      #
      # @return [void]
      def reload
        @mutex.synchronize do
          @areas = nil
          @categories = nil
        end
      end

      private

      def get(path)
        response = Connection.perform { @connection.get(path) }

        unless response.success?
          raise ResponseError.new(
            "reference request failed with HTTP #{response.status}",
            status: response.status,
            body: response.body
          )
        end

        parsed = JSON.parse(response.body.to_s)
        parsed.is_a?(Array) ? parsed : []
      rescue JSON::ParserError => e
        raise ParseError, "reference service returned invalid JSON: #{e.message}"
      end
    end
  end
end
