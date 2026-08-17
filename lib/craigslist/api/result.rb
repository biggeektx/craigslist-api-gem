# frozen_string_literal: true

module Craigslist
  module API
    # The outcome of a single posting within a bulk submission.
    #
    # Bulk submissions succeed and fail per item, and the HTTP status says
    # nothing about it — a 200 can carry a document in which every posting
    # failed. So submissions return results rather than raising: a batch with a
    # few rejections is ordinary, not exceptional.
    class Result
      # Returned by validate when the posting looks acceptable.
      VALID = "VALID"

      # Validation failed. {#explanation} says why.
      NOT_VALID = "NOT_VALID"

      # The posting was accepted.
      POSTED = "POSTED"

      # Unexpected error at post time.
      FAILED = "FAILED"

      # The account has no remaining blocks for this area/category and is not
      # invoiced. More must be purchased before the posting is processed.
      INSUFFICIENT_BLOCKS = "INSUFFICIENT_BLOCKS"

      # The invoiced account hit its credit limit.
      CREDIT_LIMIT_REACHED = "CREDIT_LIMIT_REACHED"

      # Billing the card named by +cl:purchaseWithCreditCardID+ failed.
      CREDIT_CARD_ERROR = "CREDIT_CARD_ERROR"

      # @return [String] the key you supplied for this posting
      attr_reader :key

      # @return [String, nil] one of the status constants above
      attr_reader :status

      # @return [String, nil] human-readable detail, populated on failure
      attr_reader :explanation

      # @return [String, nil] craigslist's id for the new posting, on success
      attr_reader :posting_id

      # @return [String, nil] URL for editing or deleting the posting
      attr_reader :manage_url

      # @return [String, nil] public URL of the posting
      attr_reader :view_url

      # @return [String, nil] HTML preview of the posting as submitted
      attr_reader :preview_html

      # @return [Array<String>] non-fatal warnings, typically XML parsing
      #   complaints. Worth logging even when the posting succeeded.
      attr_reader :warnings

      def initialize(key:, status: nil, explanation: nil, posting_id: nil,
        manage_url: nil, view_url: nil, preview_html: nil, warnings: [])
        @key = key
        @status = status
        @explanation = explanation
        @posting_id = posting_id
        @manage_url = manage_url
        @view_url = view_url
        @preview_html = preview_html
        @warnings = Array(warnings).freeze
        freeze
      end

      # @return [Boolean] validated successfully (validate mode only)
      def valid?
        status == VALID
      end

      # @return [Boolean] accepted for posting (post mode only)
      def posted?
        status == POSTED
      end

      # @return [Boolean] either valid or posted
      def success?
        valid? || posted?
      end

      # @return [Boolean]
      def failure?
        !success?
      end

      # @return [Boolean] rejected during validation
      def not_valid?
        status == NOT_VALID
      end

      # @return [Boolean] the account is out of posting blocks
      def insufficient_blocks?
        status == INSUFFICIENT_BLOCKS
      end

      # @return [Boolean] the invoiced account hit its credit limit
      def credit_limit_reached?
        status == CREDIT_LIMIT_REACHED
      end

      # @return [Boolean] the credit card could not be billed
      def credit_card_error?
        status == CREDIT_CARD_ERROR
      end

      # @return [Boolean] whether any non-fatal warnings came back
      def warnings?
        !warnings.empty?
      end

      def inspect
        "#<#{self.class.name} key=#{key.inspect} status=#{status.inspect} " \
          "posting_id=#{posting_id.inspect}>"
      end
    end
  end
end
