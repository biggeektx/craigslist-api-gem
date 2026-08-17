# frozen_string_literal: true

module Craigslist
  module API
    module Resources
      # Account credit, prepaid posting blocks, pricing, and invoicing.
      class Billing < Base
        # @return [CreditSummary]
        def credit
          CreditSummary.from(transport.get(path("account", "billing", "credit")).data)
        end

        # Prepaid blocks still available, per area and product.
        #
        # @return [Array<PostingBlock>]
        def posting_blocks
          Array(transport.get(path("account", "billing", "posting-block-balances")).data)
            .map { |entry| PostingBlock.from(entry) }
        end

        # Current cost of posting in an area and category.
        #
        # Prices can change without notice, so treat the result as a quote
        # rather than something to cache.
        #
        # @param area [String] area abbreviation, e.g. "sfo"
        # @param category [String] category abbreviation, e.g. "ofc"
        # @return [Money, nil]
        def pricing(area:, category:)
          data = transport.get(
            path("account", "billing", "current-pricing", "area", area, "category", category)
          ).data || {}

          Money.from(data["currentPricing"])
        end

        # Invoices everything not yet invoiced, ahead of the normal cycle.
        #
        # @return [Array<String>] ids of the invoices created
        def create_invoice
          data = transport.post(path("account", "billing", "make-invoice")).data || {}
          Array(data["invoiceIDs"]).map(&:to_s)
        end
      end
    end
  end
end
