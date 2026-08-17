# frozen_string_literal: true

require "rexml/document"

module Craigslist
  module API
    # Turns the RSS document returned by validate/post into a {ResultSet}.
    #
    # Element lookups use the literal prefixed names as they appear on the wire
    # rather than XPath namespace resolution, which REXML handles awkwardly when
    # a default namespace is in play.
    class ResponseParser
      UPLOAD_ID_PREFIX = "upload-id:"

      class << self
        # @param xml [String] raw response body
        # @return [ResultSet]
        # @raise [ParseError] if the body is not well-formed XML
        def parse(xml)
          document = build(xml)
          root = document.root
          raise ParseError, "response contained no root element" if root.nil?

          new(root).result_set
        end

        private

        def build(xml)
          REXML::Document.new(xml.to_s)
        rescue REXML::ParseException => e
          raise ParseError, "could not parse the bulk posting response: #{e.message}"
        end
      end

      def initialize(root)
        @root = root
      end

      # @return [ResultSet]
      def result_set
        ResultSet.new(results: results, upload_id: upload_id)
      end

      private

      attr_reader :root

      def results
        root.get_elements("item").map { |item| build_result(item) }
      end

      def build_result(item)
        Result.new(
          key: item.attributes["rdf:about"].to_s,
          status: value_of(item, "cl:postedStatus"),
          explanation: value_of(item, "cl:postedExplanation"),
          posting_id: value_of(item, "cl:postingID"),
          manage_url: value_of(item, "cl:postingManageURL"),
          view_url: value_of(item, "cl:postingViewURL"),
          preview_html: value_of(item, "cl:previewHTML"),
          warnings: item.get_elements("cl:warning").filter_map { |w| text_of(w) }
        )
      end

      def upload_id
        description = root.get_elements("channel/description").first
        text = text_of(description)
        return nil if text.nil? || !text.start_with?(UPLOAD_ID_PREFIX)

        text.delete_prefix(UPLOAD_ID_PREFIX)
      end

      def value_of(parent, name)
        text_of(parent.get_elements(name).first)
      end

      # Reads every text child, CDATA included, and strips surrounding
      # whitespace — craigslist pretty-prints URLs onto their own lines, which
      # leaves newlines inside the element.
      def text_of(element)
        return nil if element.nil?

        text = element.texts.map(&:value).join.strip
        text.empty? ? nil : text
      end
    end
  end
end
