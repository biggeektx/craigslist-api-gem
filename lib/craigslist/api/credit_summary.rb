# frozen_string_literal: true

module Craigslist
  module API
    # Credit standing for an invoiced account.
    class CreditSummary
      # @return [Money, nil] total credit extended
      attr_reader :credit_line

      # @return [Money, nil] credit still available
      attr_reader :remaining

      # @return [Money, nil] credit consumed so far
      attr_reader :used

      def initialize(credit_line: nil, remaining: nil, used: nil)
        @credit_line = credit_line
        @remaining = remaining
        @used = used
        freeze
      end

      # @param hash [Hash] raw payload
      # @return [CreditSummary]
      def self.from(hash)
        hash ||= {}
        new(
          credit_line: Money.from(hash["creditLine"]),
          remaining: Money.from(hash["creditRemaining"]),
          used: Money.from(hash["creditUsed"])
        )
      end

      def inspect
        "#<#{self.class.name} line=#{credit_line} remaining=#{remaining} used=#{used}>"
      end
    end
  end
end
