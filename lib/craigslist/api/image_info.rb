# frozen_string_literal: true

module Craigslist
  module API
    # Metadata about an image attached to a live posting.
    class ImageInfo
      # @return [String] craigslist's image id, e.g. "4:00101_b1ztTgNtBAU"
      attr_reader :id

      # @return [String, nil]
      attr_reader :filename

      # @return [String, nil] e.g. "JPEG", "GIF", "WEBP"
      attr_reader :format

      # @return [Integer, nil]
      attr_reader :width

      # @return [Integer, nil]
      attr_reader :height

      # @return [Integer, nil] zero-based position within the posting
      attr_reader :position

      def initialize(id:, filename: nil, format: nil, width: nil, height: nil, position: nil)
        @id = id
        @filename = filename
        @format = format
        @width = width
        @height = height
        @position = position
        freeze
      end

      # @param hash [Hash] raw payload
      # @return [ImageInfo]
      def self.from(hash)
        new(
          id: hash["id"],
          filename: hash["filename"],
          format: hash["format"],
          width: hash["width"],
          height: hash["height"],
          position: hash["position"]
        )
      end

      def inspect
        "#<#{self.class.name} id=#{id.inspect} position=#{position.inspect} #{width}x#{height} #{format}>"
      end
    end
  end
end
