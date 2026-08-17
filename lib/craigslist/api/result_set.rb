# frozen_string_literal: true

module Craigslist
  module API
    # Every {Result} from one bulk submission, plus the upload id Craigslist
    # assigns to the batch.
    #
    # Enumerable, so it behaves like the array of results it wraps while still
    # answering the questions you actually have after a submission.
    class ResultSet
      include Enumerable

      # @return [Array<Result>]
      attr_reader :results

      # @return [String, nil] craigslist's identifier for this submission,
      #   taken from the channel description. Present in post mode.
      attr_reader :upload_id

      def initialize(results:, upload_id: nil)
        @results = Array(results).freeze
        @upload_id = upload_id
        @index = @results.each_with_object({}) { |r, memo| memo[r.key] = r }.freeze
        freeze
      end

      # @yieldparam result [Result]
      # @return [Enumerator, ResultSet]
      def each(&block)
        results.each(&block)
      end

      # @param key [String] the key supplied when building the posting
      # @return [Result, nil]
      def [](key)
        @index[key.to_s]
      end

      # @return [Array<Result>]
      def successful
        select(&:success?)
      end

      # @return [Array<Result>]
      def failed
        select(&:failure?)
      end

      # @return [Array<Result>] results carrying non-fatal warnings, which are
      #   easy to miss because they can accompany a success
      def warned
        select(&:warnings?)
      end

      # @return [Boolean] whether every posting succeeded
      def all_successful?
        failed.empty?
      end

      # @return [Boolean]
      def any_failures?
        !failed.empty?
      end

      # @return [Array<String>] ids of postings that were created
      def posting_ids
        select(&:posted?).map(&:posting_id).compact
      end

      # @return [Integer] number of results in the batch
      def size
        results.size
      end
      alias_method :length, :size

      def empty?
        results.empty?
      end

      def inspect
        "#<#{self.class.name} size=#{size} successful=#{successful.size} " \
          "failed=#{failed.size} upload_id=#{upload_id.inspect}>"
      end
    end
  end
end
