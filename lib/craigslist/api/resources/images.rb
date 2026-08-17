# frozen_string_literal: true

require "faraday/multipart"
require "pathname"

module Craigslist
  module API
    module Resources
      # Images on a live posting.
      #
      # Note the API's verb choices are inverted from the usual convention:
      # PUT uploads a new image, POST reorders the existing ones. The method
      # names here describe the effect rather than the verb.
      class Images < Base
        DEFAULT_CONTENT_TYPE = "image/jpeg"

        # @param posting_id [String, Integer]
        # @return [Array<ImageInfo>] ordered as they appear on the posting
        def list(posting_id)
          data = transport.get(path("postings", posting_id, "images")).data || {}
          Array(data["imageInfo"]).map { |info| ImageInfo.from(info) }
        end

        # Uploads an image and attaches it to the posting.
        #
        # With neither position given the image is appended. Positions are
        # zero-based.
        #
        # @param posting_id [String, Integer]
        # @param source [String, Pathname, IO] the image
        # @param filename [String, nil] defaults to the basename of a path
        # @param content_type [String]
        # @param insert_position [Integer, nil] insert at this position
        # @param replace_position [Integer, nil] replace the image here
        # @return [ImageInfo] the newly attached image
        # @raise [ValidationError] if both positions are given
        def upload(posting_id, source, filename: nil, content_type: DEFAULT_CONTENT_TYPE,
          insert_position: nil, replace_position: nil)
          if !insert_position.nil? && !replace_position.nil?
            raise ValidationError, ["pass insert_position or replace_position, not both"]
          end

          fields = {}
          fields["insert_position"] = insert_position.to_s unless insert_position.nil?
          fields["replace_position"] = replace_position.to_s unless replace_position.nil?

          envelope = transport.upload(
            path("postings", posting_id, "images"),
            part: file_part(source, filename, content_type),
            fields: fields
          )

          ImageInfo.from((envelope.data || {})["imageInfo"] || {})
        end

        # Sets the order of the posting's images.
        #
        # @param posting_id [String, Integer]
        # @param image_ids [Array<String>] every image id, in the desired order
        # @return [true]
        def reorder(posting_id, image_ids)
          transport.post(
            path("postings", posting_id, "images"),
            form: {"imageIdList" => Array(image_ids).join(",")}
          )
          true
        end

        # Detaches an image from the posting.
        #
        # The image itself is not destroyed — it stays publicly retrievable and
        # can still be referenced by other postings.
        #
        # @param posting_id [String, Integer]
        # @param image_id [String]
        # @return [true]
        def remove(posting_id, image_id)
          transport.delete(path("postings", posting_id, "images", image_id))
          true
        end

        private

        def file_part(source, filename, content_type)
          case source
          when Pathname, String
            Faraday::Multipart::FilePart.new(
              source.to_s,
              content_type,
              filename || File.basename(source.to_s)
            )
          else
            unless source.respond_to?(:read)
              raise ValidationError, ["cannot upload a #{source.class}; pass a path or an IO"]
            end

            Faraday::Multipart::FilePart.new(source, content_type, filename || "upload.jpg")
          end
        end
      end
    end
  end
end
