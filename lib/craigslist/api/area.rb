# frozen_string_literal: true

module Craigslist
  module API
    # A craigslist area (a city or region), as published by the public
    # reference service.
    class Area
      # A subdivision of an {Area}. Postings in areas that have subareas are
      # expected to name one.
      class SubArea
        attr_reader :abbreviation, :description, :short_description, :id

        def initialize(abbreviation:, description: nil, short_description: nil, id: nil)
          @abbreviation = abbreviation
          @description = description
          @short_description = short_description
          @id = id
          freeze
        end

        # @param hash [Hash] raw payload
        # @return [SubArea]
        def self.from(hash)
          new(
            abbreviation: hash["Abbreviation"],
            description: hash["Description"],
            short_description: hash["ShortDescription"],
            id: hash["SubAreaID"]
          )
        end

        def to_s
          abbreviation.to_s
        end

        def inspect
          "#<#{self.class.name} #{abbreviation.inspect} #{description.inspect}>"
        end
      end

      attr_reader :abbreviation, :description, :short_description, :hostname,
        :country, :region, :latitude, :longitude, :id, :subareas

      def initialize(abbreviation:, description: nil, short_description: nil,
        hostname: nil, country: nil, region: nil, latitude: nil,
        longitude: nil, id: nil, subareas: [])
        @abbreviation = abbreviation
        @description = description
        @short_description = short_description
        @hostname = hostname
        @country = country
        @region = region
        @latitude = latitude
        @longitude = longitude
        @id = id
        @subareas = subareas.freeze
        freeze
      end

      # @param hash [Hash] raw payload
      # @return [Area]
      def self.from(hash)
        new(
          abbreviation: hash["Abbreviation"],
          description: hash["Description"],
          short_description: hash["ShortDescription"],
          hostname: hash["Hostname"],
          country: hash["Country"],
          region: hash["Region"],
          latitude: hash["Latitude"],
          longitude: hash["Longitude"],
          id: hash["AreaID"],
          subareas: Array(hash["SubAreas"]).map { |sub| SubArea.from(sub) }
        )
      end

      # @return [Boolean] whether a subarea must be supplied when posting here
      def subareas?
        !subareas.empty?
      end

      # @param abbreviation [String]
      # @return [SubArea, nil]
      def subarea(abbreviation)
        subareas.find { |sub| sub.abbreviation == abbreviation.to_s }
      end

      def to_s
        abbreviation.to_s
      end

      def inspect
        "#<#{self.class.name} #{abbreviation.inspect} #{description.inspect} " \
          "subareas=#{subareas.size}>"
      end
    end
  end
end
