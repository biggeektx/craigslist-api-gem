# frozen_string_literal: true

module Craigslist
  module API
    # A posting to be submitted through the bulk RSS interface.
    #
    # Validated on construction, so a malformed posting fails locally instead of
    # consuming a round trip. Everything is frozen afterwards.
    #
    # The interface exposes two generations of optional fields. This models the
    # newer flat attribute groups (+cl:housing_basics+, +cl:job_basics+,
    # +cl:auto_basics+, +cl:forsale+, +cl:generic+, +cl:housing_terms+,
    # +cl:housing_pets+), whose keys are already snake_case and pass through
    # unchanged. The legacy camelCase groups (+cl:housingInfo+, +cl:jobInfo+)
    # are not modelled; +cl:brokerInfo+ is, because housing postings still need
    # it and it has no modern equivalent.
    #
    # @example A minimal for-sale posting
    #   Craigslist::API::Posting.new(
    #     key: "listing-1",
    #     title: "1998 Toyota Hilux",
    #     description: "Runs great.",
    #     category: "ctd",
    #     area: "sfo",
    #     price: 4500,
    #     reply_email: "sales@example.com",
    #     location: {postal: "94110"}
    #   )
    class Posting
      # How the reply address is displayed on the posting.
      PRIVACY = {
        none: "A",        # show no email address
        anonymous: "C",   # use an anonymous craigslist relay address
        public: "P"       # show the address as given
      }.freeze

      # Ruby-side names for +cl:mapLocation+ attributes, which are camelCase on
      # the wire.
      LOCATION_ATTRIBUTES = {
        postal: "postal",
        city: "city",
        state: "state",
        cross_street1: "crossStreet1",
        cross_street2: "crossStreet2",
        latitude: "latitude",
        longitude: "longitude"
      }.freeze

      # Ruby-side names for +cl:brokerInfo+ attributes.
      BROKER_ATTRIBUTES = {
        company_name: "companyName",
        fee_disclosure: "feeDisclosure"
      }.freeze

      attr_reader :key, :title, :description, :category, :area, :subarea,
        :neighborhood, :price, :po_number, :reply_email, :reply_privacy,
        :other_contact_info, :location, :images, :broker, :generic,
        :housing_basics, :housing_pets, :housing_terms, :job_basics,
        :auto_basics, :forsale

      # @param key [String] identifier unique within the submission document.
      #   Echoed back on the matching result, and how you correlate a response
      #   to what you sent.
      # @param title [String]
      # @param description [String] the posting body
      # @param category [String] category abbreviation, e.g. "ctd"
      # @param area [String] area abbreviation, e.g. "sfo"
      # @param subarea [String, nil] required in areas that have subareas
      # @param neighborhood [String, nil]
      # @param price [Integer, nil]
      # @param po_number [String, nil] your own tracking reference
      # @param reply_email [String, nil]
      # @param reply_privacy [Symbol, String] one of +:none+, +:anonymous+,
      #   +:public+, or a raw "A"/"C"/"P"
      # @param other_contact_info [String, nil] free-text alternate contact
      # @param location [Hash] see {LOCATION_ATTRIBUTES}. Either +:postal+ or
      #   both +:latitude+ and +:longitude+ is required.
      # @param images [Array<Image, IO, String, Pathname>] see {Image.wrap}
      # @param broker [Hash] see {BROKER_ATTRIBUTES}
      # @param generic [Hash] +cl:generic+ attributes
      # @param housing_basics [Hash] +cl:housing_basics+ attributes
      # @param housing_pets [Hash] +cl:housing_pets+ attributes
      # @param housing_terms [Hash] +cl:housing_terms+ attributes
      # @param job_basics [Hash] +cl:job_basics+ attributes
      # @param auto_basics [Hash] +cl:auto_basics+ attributes
      # @param forsale [Hash] +cl:forsale+ attributes
      # @raise [ValidationError] if anything required is missing
      def initialize(
        key:,
        title:,
        description:,
        category:,
        area:,
        subarea: nil,
        neighborhood: nil,
        price: nil,
        po_number: nil,
        reply_email: nil,
        reply_privacy: :anonymous,
        other_contact_info: nil,
        location: {},
        images: [],
        broker: {},
        generic: {},
        housing_basics: {},
        housing_pets: {},
        housing_terms: {},
        job_basics: {},
        auto_basics: {},
        forsale: {}
      )
        @key = key.to_s
        @title = title.to_s
        @description = description.to_s
        @category = category.to_s
        @area = area.to_s
        @subarea = subarea&.to_s
        @neighborhood = neighborhood&.to_s
        @price = price
        @po_number = po_number&.to_s
        @reply_email = reply_email&.to_s
        @reply_privacy = normalize_privacy(reply_privacy)
        @other_contact_info = other_contact_info&.to_s
        @location = compact(location).freeze
        @images = build_images(images).freeze
        @broker = compact(broker).freeze
        @generic = compact(generic).freeze
        @housing_basics = compact(housing_basics).freeze
        @housing_pets = compact(housing_pets).freeze
        @housing_terms = compact(housing_terms).freeze
        @job_basics = compact(job_basics).freeze
        @auto_basics = compact(auto_basics).freeze
        @forsale = compact(forsale).freeze

        validate!
        freeze
      end

      # @return [Array<String>] problems with this posting, empty when valid
      def errors
        problems = []
        problems << "key is required" if key.empty?
        problems << "title is required" if title.empty?
        problems << "description is required" if description.empty?
        problems << "category is required" if category.empty?
        problems << "area is required" if area.empty?
        problems.concat(location_errors)
        problems.concat(image_errors)
        problems
      end

      # @return [Boolean]
      def valid?
        errors.empty?
      end

      def inspect
        "#<#{self.class.name} key=#{key.inspect} category=#{category.inspect} " \
          "area=#{area.inspect} images=#{images.size}>"
      end

      private

      def validate!
        found = errors
        raise ValidationError, found unless found.empty?
      end

      def location_errors
        has_postal = !location[:postal].to_s.empty?
        has_coords = !location[:latitude].nil? && !location[:longitude].nil?
        return [] if has_postal || has_coords

        ["location requires :postal, or both :latitude and :longitude"]
      end

      def image_errors
        problems = []

        if images.size > Image::MAX_PER_POSTING
          problems << "a posting accepts at most #{Image::MAX_PER_POSTING} images, got #{images.size}"
        end

        positions = images.map(&:position).compact
        out_of_range = positions.reject { |p| p.between?(0, Image::MAX_POSITION) }
        unless out_of_range.empty?
          problems << "image positions must be 0..#{Image::MAX_POSITION}, got #{out_of_range.inspect}"
        end

        duplicates = positions.tally.select { |_, count| count > 1 }.keys
        problems << "duplicate image positions: #{duplicates.inspect}" unless duplicates.empty?

        problems
      end

      def build_images(sources)
        Array(sources).each_with_index.map do |source, index|
          Image.wrap(source).with_default_position(index)
        end
      end

      def normalize_privacy(value)
        return PRIVACY.fetch(value) if value.is_a?(Symbol) && PRIVACY.key?(value)

        string = value.to_s.upcase
        return string if PRIVACY.value?(string)

        raise ValidationError, ["reply_privacy must be one of #{PRIVACY.keys.inspect} or #{PRIVACY.values.inspect}"]
      end

      def compact(hash)
        (hash || {}).reject { |_, value| value.nil? }
      end
    end
  end
end
