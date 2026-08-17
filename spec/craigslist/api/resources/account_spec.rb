# frozen_string_literal: true

RSpec.describe Craigslist::API::Resources::Account do
  subject(:account) { build_client.account }

  before { stub_token }

  describe "#acknowledge" do
    it "PUTs to the ack endpoint" do
      stub = stub_request(:put, "#{bapi}/account/message/m1/ack")
        .to_return(json_response("message" => "account message acknowledged"))

      expect(account.acknowledge("m1")).to be(true)
      expect(stub).to have_been_requested
    end
  end

  describe "#stats" do
    let(:payload) do
      [{
        "postingId" => "7123456780",
        "impressions" => [[1_746_748_800, 57], [1_746_835_200, 841]],
        "views" => [[1_746_748_800, 4], [1_746_835_200, 19]],
        "contact_email" => [[1_746_748_800, 3]]
      }]
    end

    it "converts timestamps to UTC times" do
      stub_request(:get, "#{bapi}/account/stats/all-postings").to_return(json_response(payload))

      stats = account.stats.first

      expect(stats.posting_id).to eq("7123456780")
      expect(stats[:impressions].first).to eq([Time.at(1_746_748_800).utc, 57])
    end

    it "totals a metric across the window" do
      stub_request(:get, "#{bapi}/account/stats/all-postings").to_return(json_response(payload))

      stats = account.stats.first

      expect(stats.total(:impressions)).to eq(898)
      expect(stats.total_views).to eq(23)
    end

    it "returns an empty series for a metric that was not reported" do
      stub_request(:get, "#{bapi}/account/stats/all-postings").to_return(json_response(payload))

      expect(account.stats.first[:favorite]).to eq([])
      expect(account.stats.first.total(:favorite)).to eq(0)
    end

    it "passes a date window as query parameters" do
      stub = stub_request(:get, "#{bapi}/account/stats/all-postings")
        .with(query: {"start" => "2026-01-01", "stop" => "2026-01-31"})
        .to_return(json_response([]))

      account.stats(start: "2026-01-01", stop: "2026-01-31")

      expect(stub).to have_been_requested
    end

    it "formats Date and Time objects for the window" do
      stub = stub_request(:get, "#{bapi}/account/stats/all-postings")
        .with(query: {"start" => "2026-03-04"})
        .to_return(json_response([]))

      account.stats(start: Time.utc(2026, 3, 4, 9, 30))

      expect(stub).to have_been_requested
    end
  end

  describe "#posting_stats" do
    it "unwraps the single-element array this endpoint returns" do
      stub_request(:get, "#{bapi}/account/stats/posting/7123456780")
        .to_return(json_response([{"views" => [[1_746_748_800, 4]]}]))

      stats = account.posting_stats("7123456780")

      expect(stats.total_views).to eq(4)
    end

    it "backfills the posting id, which this endpoint omits" do
      stub_request(:get, "#{bapi}/account/stats/posting/7123456780")
        .to_return(json_response([{"views" => [[1_746_748_800, 4]]}]))

      expect(account.posting_stats("7123456780").posting_id).to eq("7123456780")
    end
  end
end
