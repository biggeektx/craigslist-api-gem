# frozen_string_literal: true

module Craigslist
  module API
    # A monetary amount as the Bulkpost API reports it: an integer in minor
    # units plus the exponent needed to scale it.
    #
    # +{amount: 100000, currency: "USD", exponent: 2}+ is $1,000.00.
    #
    # Conversion goes through +Rational+ rather than +Float+ so the scaling is
    # exact, and deliberately avoids +BigDecimal+, which stopped being a default
    # gem in Ruby 3.4 and would add a dependency.
    class Money
      # @return [Integer] value in minor units
      attr_reader :amount

      # @return [String] ISO 4217 currency code
      attr_reader :currency

      # @return [Integer] power of ten separating minor units from major
      attr_reader :exponent

      def initialize(amount:, currency: "USD", exponent: 2)
        @amount = amount.to_i
        @currency = currency.to_s
        @exponent = exponent.to_i
        freeze
      end

      # @param hash [Hash, nil] raw +{"amount", "currency", "exponent"}+ payload
      # @return [Money, nil]
      def self.from(hash)
        return nil if hash.nil?

        new(
          amount: hash["amount"],
          currency: hash.fetch("currency", "USD"),
          exponent: hash.fetch("exponent", 2)
        )
      end

      # @return [Rational] exact value in major units
      def to_r
        Rational(amount, 10**exponent)
      end

      # @return [Float] value in major units, with the usual float caveats
      def to_f
        to_r.to_f
      end

      # @return [String] e.g. "1000.00 USD"
      def to_s
        "#{format("%.#{exponent}f", to_r)} #{currency}"
      end

      def ==(other)
        other.is_a?(Money) &&
          amount == other.amount &&
          currency == other.currency &&
          exponent == other.exponent
      end
      alias_method :eql?, :==

      def hash
        [amount, currency, exponent].hash
      end

      def inspect
        "#<#{self.class.name} #{self}>"
      end
    end
  end
end
