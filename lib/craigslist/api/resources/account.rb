# frozen_string_literal: true

module Craigslist
  module API
    module Resources
      # Account notices and posting statistics.
      class Account < Base
        # Acknowledges an account message so it stops appearing on subsequent
        # responses.
        #
        # Craigslist attaches these notices to every response until they are
        # acknowledged, which is why {Client#account_messages} exists.
        #
        # @param message_id [String]
        # @return [true]
        def acknowledge(message_id)
          transport.put(path("account", "message", message_id, "ack"))
          true
        end

        # Engagement statistics for every posting on the account.
        #
        # @param start [String, Date, Time, nil] window start, "yyyy-mm-dd".
        #   Defaults server-side to 31 days ago.
        # @param stop [String, Date, Time, nil] window end, "yyyy-mm-dd".
        #   Defaults server-side to yesterday.
        # @return [Array<PostingStats>]
        def stats(start: nil, stop: nil)
          envelope = transport.get(
            path("account", "stats", "all-postings"),
            params: window(start, stop)
          )

          Array(envelope.data).map { |entry| PostingStats.from(entry) }
        end

        # Engagement statistics for one posting.
        #
        # @param posting_id [String, Integer]
        # @param start [String, Date, Time, nil] see {#stats}
        # @param stop [String, Date, Time, nil] see {#stats}
        # @return [PostingStats]
        def posting_stats(posting_id, start: nil, stop: nil)
          envelope = transport.get(
            path("account", "stats", "posting", posting_id),
            params: window(start, stop)
          )

          # This endpoint returns a single-element array rather than an object.
          payload = envelope.data.is_a?(Array) ? envelope.data.first : envelope.data
          stats = PostingStats.from(payload || {})

          return stats unless stats.posting_id.nil?

          PostingStats.new(posting_id: posting_id.to_s, series: stats.series)
        end

        private

        def window(start, stop)
          {"start" => format_date(start), "stop" => format_date(stop)}.compact
        end

        def format_date(value)
          return nil if value.nil?
          return value if value.is_a?(String)

          value.strftime("%Y-%m-%d")
        end
      end
    end
  end
end
