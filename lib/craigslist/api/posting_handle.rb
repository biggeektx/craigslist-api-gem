# frozen_string_literal: true

module Craigslist
  module API
    # A live posting, addressed by id.
    #
    # Returned by {Client#posting}. Holds no state of its own beyond the id —
    # every reader hits the API — so it is safe to keep around, and it never
    # goes stale.
    #
    # @example
    #   posting = client.posting("7123456780")
    #   posting.status          #=> "active"
    #   posting.price = 4200
    #   posting.add_image("photo.jpg")
    #   posting.delete
    class PostingHandle
      # @return [String]
      attr_reader :id

      def initialize(client, id)
        @client = client
        @id = id.to_s
      end

      # @return [String] one of {Resources::Postings::STATUSES}
      def status
        client.postings.status(id)
      end

      # @return [Boolean]
      def active?
        status == "active"
      end

      # @return [Boolean]
      def deleted?
        status == "deleted"
      end

      # @return [Boolean]
      def expired?
        status == "expired"
      end

      # @return [String]
      def body
        client.postings.body(id)
      end

      # @param value [String]
      # @return [String]
      def update_body(value)
        client.postings.update_body(id, value)
      end

      # @param value [String]
      def body=(value)
        update_body(value)
      end

      # @return [Integer, nil]
      def price
        client.postings.price(id)
      end

      # @param value [Integer]
      # @return [Integer]
      def update_price(value)
        client.postings.update_price(id, value)
      end

      # @param value [Integer]
      def price=(value)
        update_price(value)
      end

      # @return [String, nil]
      def remuneration
        client.postings.remuneration(id)
      end

      # @param value [String]
      # @return [String]
      def update_remuneration(value)
        client.postings.update_remuneration(id, value)
      end

      # @param value [String]
      def remuneration=(value)
        update_remuneration(value)
      end

      # @return [true]
      def delete
        client.postings.delete(id)
      end

      # @return [true]
      def undelete
        client.postings.undelete(id)
      end

      # @return [Array<ImageInfo>]
      def images
        client.images.list(id)
      end

      # @see Resources::Images#upload
      # @return [ImageInfo]
      def add_image(source, **options)
        client.images.upload(id, source, **options)
      end

      # @param image_id [String]
      # @return [true]
      def remove_image(image_id)
        client.images.remove(id, image_id)
      end

      # @param image_ids [Array<String>]
      # @return [true]
      def reorder_images(image_ids)
        client.images.reorder(id, image_ids)
      end

      # @see Resources::Account#posting_stats
      # @return [PostingStats]
      def stats(start: nil, stop: nil)
        client.account.posting_stats(id, start: start, stop: stop)
      end

      def inspect
        "#<#{self.class.name} id=#{id.inspect}>"
      end

      private

      attr_reader :client
    end
  end
end
