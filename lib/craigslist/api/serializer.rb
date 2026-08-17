# frozen_string_literal: true

require "rexml/document"

module Craigslist
  module API
    # Renders {Posting} objects into the RDF/RSS document the bulk interface
    # expects.
    #
    # REXML lives here and nowhere else. Bulk submissions inline base64 images,
    # so a large batch is a large document; if building a DOM ever becomes a
    # memory problem this class can be reimplemented as a streaming writer
    # without changing anything public.
    class Serializer
      RSS_NAMESPACE = "http://purl.org/rss/1.0/"
      RDF_NAMESPACE = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
      CL_NAMESPACE = "http://www.craigslist.org/about/cl-bulk-ns/1.0"

      # @param config [Configuration] supplies the +cl:auth+ credentials
      def initialize(config)
        @config = config
      end

      # @param postings [Array<Posting>]
      # @param io [IO, String, nil] destination; a new String is used if omitted
      # @return [String, IO] whatever was written to
      def serialize(postings, io: nil)
        output = io || +""
        build_document(Array(postings)).write(output)
        output
      end

      private

      attr_reader :config

      def build_document(postings)
        doc = REXML::Document.new
        doc << REXML::XMLDecl.new("1.0", "UTF-8")

        root = doc.add_element("rdf:RDF",
          "xmlns" => RSS_NAMESPACE,
          "xmlns:rdf" => RDF_NAMESPACE,
          "xmlns:cl" => CL_NAMESPACE)

        append_channel(root, postings)
        postings.each { |posting| append_item(root, posting) }

        doc
      end

      def append_channel(root, postings)
        channel = root.add_element("channel")

        items = channel.add_element("items")
        postings.each do |posting|
          items.add_element("rdf:li", "rdf:resource" => posting.key)
        end

        channel.add_element("cl:auth",
          "username" => config.email,
          "password" => config.password,
          "accountID" => config.account_id)
      end

      def append_item(root, posting)
        item = root.add_element("item", "rdf:about" => posting.key)

        text_element(item, "cl:category", posting.category)
        text_element(item, "cl:area", posting.area)
        text_element(item, "cl:subarea", posting.subarea)
        text_element(item, "cl:neighborhood", posting.neighborhood)
        text_element(item, "cl:price", posting.price)

        attribute_element(item, "cl:housing_basics", posting.housing_basics)
        attribute_element(item, "cl:housing_pets", posting.housing_pets)
        attribute_element(item, "cl:housing_terms", posting.housing_terms)
        attribute_element(item, "cl:job_basics", posting.job_basics)
        attribute_element(item, "cl:auto_basics", posting.auto_basics)
        attribute_element(item, "cl:forsale", posting.forsale)
        attribute_element(item, "cl:generic", posting.generic)

        attribute_element(item, "cl:mapLocation",
          rename(posting.location, Posting::LOCATION_ATTRIBUTES))
        append_reply_email(item, posting)
        attribute_element(item, "cl:brokerInfo",
          rename(posting.broker, Posting::BROKER_ATTRIBUTES))

        text_element(item, "title", posting.title)
        cdata_element(item, "description", posting.description)
        text_element(item, "cl:PONumber", posting.po_number)

        posting.images.each { |image| append_image(item, image) }
      end

      def append_reply_email(item, posting)
        return if posting.reply_email.nil? || posting.reply_email.empty?

        attributes = {"privacy" => posting.reply_privacy}
        unless posting.other_contact_info.nil? || posting.other_contact_info.empty?
          attributes["otherContactInfo"] = posting.other_contact_info
        end

        item.add_element("cl:replyEmail", attributes).add_text(posting.reply_email)
      end

      def append_image(item, image)
        attributes = image.position.nil? ? {} : {"position" => image.position.to_s}
        element = item.add_element("cl:image", attributes)

        # Written raw: base64 is alphanumeric plus "+/=", so it needs no
        # escaping, and skipping the escape pass matters on megabyte payloads.
        element.add(REXML::Text.new(image.data, true, nil, true))
      end

      def text_element(parent, name, value)
        return if value.nil? || value.to_s.empty?

        parent.add_element(name).add_text(value.to_s)
      end

      # Emits text as CDATA, split around any literal "]]>".
      #
      # A "]]>" in a posting body would otherwise close the section early and
      # corrupt the whole document. REXML does not guard against this and
      # posting bodies are arbitrary user text, so split the run across
      # adjacent sections: "a]]>b" becomes CDATA("a]]") + CDATA(">b"), which
      # concatenates back to the original on the far end.
      def cdata_element(parent, name, value)
        element = parent.add_element(name)
        chunks = value.to_s.split("]]>", -1)
        final = chunks.size - 1

        chunks.each_with_index do |chunk, index|
          content = +""
          content << ">" unless index.zero?
          content << chunk
          content << "]]" unless index == final

          element.add(REXML::CData.new(content))
        end

        element
      end

      def attribute_element(parent, name, attributes)
        return if attributes.nil? || attributes.empty?

        parent.add_element(name, stringify(attributes))
      end

      def rename(hash, mapping)
        hash.each_with_object({}) do |(key, value), memo|
          memo[mapping.fetch(key.to_sym, key.to_s)] = value
        end
      end

      # The interface expresses booleans as 0/1, so accept Ruby booleans and
      # translate rather than making callers remember.
      def stringify(hash)
        hash.each_with_object({}) do |(key, value), memo|
          memo[key.to_s] =
            case value
            when true then "1"
            when false then "0"
            else value.to_s
            end
        end
      end
    end
  end
end
