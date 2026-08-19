# frozen_string_literal: true

module Craigslist
  module API
    # Where a US ZIP code maps to on craigslist.
    #
    # Carries a subarea when the ZIP resolves to one. That matters more than it
    # looks: subarea is required in every area that has subareas, and omitting
    # it is the most common reason a posting comes back NOT_VALID.
    #
    # @example Feeding a posting directly
    #   place = client.area_for_zip("94110")
    #   place.area      #=> "sfo"
    #   place.subarea   #=> "sfc"
    #
    #   Craigslist::API::Posting.new(**place.to_h, key: ..., title: ...)
    class ZipLocation
      # @return [String, nil] area abbreviation, e.g. "sfo"
      attr_reader :area

      # @return [String, nil] e.g. "SF bay area"
      attr_reader :area_description

      # @return [String, nil] subarea abbreviation, e.g. "sfc"
      attr_reader :subarea

      # @return [String, nil] e.g. "city of san francisco"
      attr_reader :subarea_description

      def initialize(area: nil, area_description: nil, subarea: nil, subarea_description: nil)
        @area = area
        @area_description = area_description
        @subarea = subarea
        @subarea_description = subarea_description
        freeze
      end

      # Builds from the endpoint payload.
      #
      # The live API nests under "area" and "subarea". The published OpenAPI
      # spec documents a flat shape instead, so both are accepted.
      #
      # @param data [Hash, nil]
      # @return [ZipLocation]
      def self.from(data)
        data ||= {}
        nested = data["area"]

        if nested.is_a?(Hash)
          sub = data["subarea"].is_a?(Hash) ? data["subarea"] : {}
          new(
            area: nested["abbreviation"],
            area_description: nested["description"],
            subarea: sub["abbreviation"],
            subarea_description: sub["description"]
          )
        else
          new(area: data["abbreviation"], area_description: data["description"])
        end
      end

      # @return [Boolean] whether this ZIP resolved to a subarea
      def subarea?
        !subarea.nil?
      end

      # Posting keywords, ready to splat. Omits +:subarea+ when there is none,
      # rather than passing an explicit nil.
      #
      # @return [Hash]
      def to_h
        subarea? ? {area: area, subarea: subarea} : {area: area}
      end

      def inspect
        "#<#{self.class.name} area=#{area.inspect} subarea=#{subarea.inspect}>"
      end
    end
  end
end
