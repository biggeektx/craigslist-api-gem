# frozen_string_literal: true

module Craigslist
  module API
    # A craigslist posting category, as published by the public reference
    # service.
    class Category
      # Categories the bulk posting interface explicitly does not support.
      # Submitting to one of these is documented as something not to do.
      UNSUPPORTED = %w[sbw rew swp sub reo prk hou sha].freeze

      attr_reader :abbreviation, :description, :type, :id

      def initialize(abbreviation:, description: nil, type: nil, id: nil)
        @abbreviation = abbreviation
        @description = description
        @type = type
        @id = id
        freeze
      end

      # @param hash [Hash] raw payload
      # @return [Category]
      def self.from(hash)
        new(
          abbreviation: hash["Abbreviation"],
          description: hash["Description"],
          type: hash["Type"],
          id: hash["CategoryID"]
        )
      end

      # @return [Boolean] whether bulk posting to this category is disallowed
      def unsupported?
        UNSUPPORTED.include?(abbreviation)
      end

      def to_s
        abbreviation.to_s
      end

      def inspect
        "#<#{self.class.name} #{abbreviation.inspect} #{description.inspect} type=#{type.inspect}>"
      end
    end
  end
end
