# frozen_string_literal: true

module Craigslist
  module API
    # Daily engagement counts for a posting.
    #
    # Craigslist reports each metric as +[unix_timestamp, count]+ pairs, one per
    # UTC day, over a rolling thirty-day window ending at midnight UTC yesterday.
    # Counts are requests, not unique viewers.
    class PostingStats
      # Every metric the API reports.
      METRICS = %i[
        impressions
        views
        contact
        contact_chat
        contact_phone
        contact_email
        share
        favorite
      ].freeze

      # @return [String, nil] absent when the stats were requested for a single
      #   posting, since the id is then already known
      attr_reader :posting_id

      # @return [Hash{Symbol => Array<Array(Time, Integer)>}]
      attr_reader :series

      def initialize(posting_id: nil, series: {})
        @posting_id = posting_id
        @series = series.freeze
        freeze
      end

      # @param hash [Hash] raw payload for one posting
      # @return [PostingStats]
      def self.from(hash)
        hash ||= {}

        series = METRICS.each_with_object({}) do |metric, memo|
          points = hash[metric.to_s]
          next if points.nil?

          memo[metric] = Array(points).map do |(timestamp, count)|
            [Time.at(timestamp.to_i).utc, count.to_i]
          end
        end

        new(posting_id: hash["postingId"], series: series)
      end

      # Time series for one metric.
      #
      # @param metric [Symbol] one of {METRICS}
      # @return [Array<Array(Time, Integer)>] empty when not reported
      def [](metric)
        series.fetch(metric.to_sym, [])
      end

      # Sum of a metric across the whole window.
      #
      # @param metric [Symbol] one of {METRICS}
      # @return [Integer]
      def total(metric)
        self[metric].sum { |(_, count)| count }
      end

      METRICS.each do |metric|
        # @return [Integer] total for this metric over the window
        define_method(:"total_#{metric}") { total(metric) }
      end

      # @return [Array<Symbol>] metrics that carry data
      def reported_metrics
        series.keys
      end

      def inspect
        "#<#{self.class.name} posting_id=#{posting_id.inspect} " \
          "metrics=#{reported_metrics.inspect}>"
      end
    end
  end
end
