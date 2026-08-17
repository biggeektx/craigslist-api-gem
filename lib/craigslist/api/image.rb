# frozen_string_literal: true

require "pathname"

module Craigslist
  module API
    # An image attached to a bulk posting.
    #
    # The RSS interface takes images inline as base64 JPEG data, up to 24 per
    # posting. Position is zero-based and the image at position 0 is the one
    # featured on search pages.
    class Image
      # Craigslist rejects postings carrying more than this many images.
      MAX_PER_POSTING = 24

      # Highest valid zero-based position.
      MAX_POSITION = MAX_PER_POSTING - 1

      # @return [String] base64-encoded image data
      attr_reader :data

      # @return [Integer, nil] zero-based position within the posting
      attr_reader :position

      # @param data [String] already base64-encoded data
      # @param position [Integer, nil]
      def initialize(data, position: nil)
        @data = data
        @position = position
        freeze
      end

      class << self
        # Coerces a caller-supplied image into an {Image}.
        #
        # Accepts an existing {Image}, an IO-like object, or a path as a String
        # or Pathname. Raw base64 has to go through {from_base64} — guessing
        # whether a String is a path or a payload would be worse than asking.
        #
        # @param source [Image, IO, Pathname, String]
        # @param position [Integer, nil]
        # @return [Image]
        # @raise [ValidationError] if the source type is not supported
        def wrap(source, position: nil)
          case source
          when Image
            position.nil? ? source : new(source.data, position: position)
          when Pathname
            from_file(source, position: position)
          when String
            from_file(source, position: position)
          else
            if source.respond_to?(:read)
              from_io(source, position: position)
            else
              raise ValidationError, ["cannot build an image from #{source.class}"]
            end
          end
        end

        # @param path [String, Pathname]
        # @return [Image]
        def from_file(path, position: nil)
          from_data(File.binread(path.to_s), position: position)
        rescue SystemCallError => e
          raise ValidationError, ["could not read image #{path}: #{e.message}"]
        end

        # @param io [IO]
        # @return [Image]
        def from_io(io, position: nil)
          io.binmode if io.respond_to?(:binmode)
          from_data(io.read, position: position)
        end

        # @param binary [String] raw (unencoded) image bytes
        # @return [Image]
        def from_data(binary, position: nil)
          # pack("m") produces RFC 2045 base64 with line breaks, matching the
          # form Craigslist's own documentation shows. Using Array#pack rather
          # than the base64 gem keeps this dependency-free on Ruby 3.4+.
          new([binary].pack("m"), position: position)
        end

        # @param encoded [String] data that is already base64
        # @return [Image]
        def from_base64(encoded, position: nil)
          new(encoded, position: position)
        end
      end

      # @return [Image] a copy pinned to +index+ when no position was set
      def with_default_position(index)
        position.nil? ? self.class.new(data, position: index) : self
      end

      def inspect
        "#<#{self.class.name} position=#{position.inspect} bytes=#{data.bytesize}>"
      end
    end
  end
end
