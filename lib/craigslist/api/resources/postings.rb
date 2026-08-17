# frozen_string_literal: true

module Craigslist
  module API
    module Resources
      # Reading and editing postings that already exist.
      #
      # Postings are created through the RSS interface ({Client#post}); this
      # covers everything afterwards.
      class Postings < Base
        # Statuses a posting can report.
        STATUSES = %w[active deleted expired pending removed].freeze

        # @param posting_id [String, Integer]
        # @return [String] one of {STATUSES}
        def status(posting_id)
          fetch(transport.get(path("postings", posting_id, "status")), "status")
        end

        # @param posting_id [String, Integer]
        # @return [String] the posting body
        def body(posting_id)
          fetch(transport.get(path("postings", posting_id, "body")), "body")
        end

        # Replaces the posting body.
        #
        # Postings in "ctd" (cars & trucks by dealer) must keep the VIN they
        # were created with; the API rejects a body that changes it.
        #
        # @param posting_id [String, Integer]
        # @param body [String]
        # @return [String] the updated body as the API echoes it back
        def update_body(posting_id, body)
          envelope = transport.put(path("postings", posting_id, "body"), form: {"body" => body})
          fetch(envelope, "body")
        end

        # @param posting_id [String, Integer]
        # @return [Integer, nil] for categories that carry a price
        def price(posting_id)
          fetch(transport.get(path("postings", posting_id, "price")), "price")
        end

        # @param posting_id [String, Integer]
        # @param price [Integer] in the currency of the posting's location
        # @return [Integer] the updated price
        def update_price(posting_id, price)
          envelope = transport.put(path("postings", posting_id, "price"), form: {"price" => price.to_i})
          fetch(envelope, "price")
        end

        # @param posting_id [String, Integer]
        # @return [String, nil] for jobs and gigs postings
        def remuneration(posting_id)
          fetch(transport.get(path("postings", posting_id, "remuneration")), "remuneration")
        end

        # @param posting_id [String, Integer]
        # @param remuneration [String] free text, e.g. "$19.95/hr plus tips"
        # @return [String] the updated value
        def update_remuneration(posting_id, remuneration)
          envelope = transport.put(
            path("postings", posting_id, "remuneration"),
            form: {"remuneration" => remuneration}
          )
          fetch(envelope, "remuneration")
        end

        # @param posting_id [String, Integer]
        # @return [true]
        def delete(posting_id)
          transport.delete(path("postings", posting_id))
          true
        end

        # @param posting_id [String, Integer]
        # @return [true]
        def undelete(posting_id)
          transport.put(path("postings", posting_id, "undelete"))
          true
        end

        # Maps a US ZIP code onto the craigslist area that covers it.
        #
        # @param zip [String]
        # @return [Hash{Symbol => String}] +{abbreviation:, description:}+
        def area_for_zip(zip)
          data = transport.get(path("posting", "zip", zip, "area")).data || {}
          {abbreviation: data["abbreviation"], description: data["description"]}
        end
      end
    end
  end
end
