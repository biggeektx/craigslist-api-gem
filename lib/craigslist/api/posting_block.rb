# frozen_string_literal: true

module Craigslist
  module API
    # Remaining prepaid posting blocks for one area/product combination.
    class PostingBlock
      # @return [String] area abbreviation, e.g. "htf"
      attr_reader :area

      # @return [String] e.g. "CAR", "JOB"
      attr_reader :product_class

      # @return [String] e.g. "hartford cars & trucks - by dealer block"
      attr_reader :product_name

      # @return [Integer] postings still available against this block
      attr_reader :remaining_posts

      def initialize(area:, product_class:, product_name:, remaining_posts:)
        @area = area
        @product_class = product_class
        @product_name = product_name
        @remaining_posts = remaining_posts.to_i
        freeze
      end

      # @param hash [Hash] raw payload
      # @return [PostingBlock]
      def self.from(hash)
        new(
          area: hash["area"],
          product_class: hash["productClass"],
          product_name: hash["productName"],
          remaining_posts: hash["remainingPosts"]
        )
      end

      def inspect
        "#<#{self.class.name} area=#{area.inspect} class=#{product_class.inspect} " \
          "remaining=#{remaining_posts}>"
      end
    end
  end
end
