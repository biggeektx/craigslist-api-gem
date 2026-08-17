# frozen_string_literal: true

require "time"

require "craigslist/api/version"
require "craigslist/api/errors"

require "craigslist/api/connection"
require "craigslist/api/configuration"

require "craigslist/api/money"
require "craigslist/api/envelope"
require "craigslist/api/access_token"
require "craigslist/api/token_provider"
require "craigslist/api/json_transport"

require "craigslist/api/image"
require "craigslist/api/posting"
require "craigslist/api/serializer"
require "craigslist/api/result"
require "craigslist/api/result_set"
require "craigslist/api/response_parser"
require "craigslist/api/bulk_transport"

require "craigslist/api/image_info"
require "craigslist/api/posting_block"
require "craigslist/api/credit_summary"
require "craigslist/api/posting_stats"
require "craigslist/api/area"
require "craigslist/api/category"
require "craigslist/api/reference"

require "craigslist/api/resources/base"
require "craigslist/api/resources/postings"
require "craigslist/api/resources/images"
require "craigslist/api/resources/billing"
require "craigslist/api/resources/account"

require "craigslist/api/posting_handle"
require "craigslist/api/client"

# Top-level namespace. This gem defines everything under {Craigslist::API}.
module Craigslist
  # Ruby client for the Craigslist bulk posting platform.
  #
  # Access to bulk posting is granted by Craigslist on a case-by-case basis to
  # high-volume posters, and is limited to paid US categories: jobs (offered),
  # apartment rentals in NYC, and for-sale-by-dealer.
  #
  # @see Client the single entry point
  module API
    # Convenience constructor.
    #
    #   client = Craigslist::API.new(email: ..., password: ..., account_id: ...)
    #
    # @see Client#initialize
    # @return [Client]
    def self.new(...)
      Client.new(...)
    end
  end
end
