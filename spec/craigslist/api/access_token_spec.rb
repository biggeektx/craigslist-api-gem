# frozen_string_literal: true

RSpec.describe Craigslist::API::AccessToken do
  let(:now) { Time.utc(2026, 1, 1, 12, 0, 0) }

  def token(expires_in: 3600)
    described_class.new(value: "abc123", expires_in: expires_in, now: now)
  end

  it "computes an expiry from the lifetime" do
    expect(token.expires_at).to eq(now + 3600)
  end

  it "formats an Authorization header value" do
    expect(token.to_header).to eq("Bearer abc123")
  end

  it "is live well before expiry" do
    expect(token.expired?(now: now + 60)).to be(false)
  end

  it "is expired after its lifetime" do
    expect(token.expired?(now: now + 3601)).to be(true)
  end

  it "expires early by the leeway, so it cannot die in flight" do
    just_inside = now + 3600 - described_class::LEEWAY + 1

    expect(token.expired?(now: just_inside)).to be(true)
  end

  describe ".from_payload" do
    it "reads the token endpoint's response" do
      built = described_class.from_payload(
        {"access_token" => "xyz", "expires_in" => 60, "token_type" => "Bearer",
         "scopes" => ["bulkpost.posting bulkpost.account.billing"]},
        now: now
      )

      expect(built.value).to eq("xyz")
      expect(built.scopes).to eq(%w[bulkpost.posting bulkpost.account.billing])
    end

    it "defaults to an hour when no lifetime is given" do
      built = described_class.from_payload({"access_token" => "xyz"}, now: now)

      expect(built.expires_at).to eq(now + 3600)
    end

    it "raises when the payload carries no token" do
      expect { described_class.from_payload({"error" => "invalid_client"}) }
        .to raise_error(Craigslist::API::AuthenticationError, /no access_token/)
    end
  end

  it "keeps the token value out of inspect output" do
    output = token.inspect

    expect(output).to include("[FILTERED]")
    expect(output).not_to include("abc123")
  end

  it "is frozen" do
    expect(token).to be_frozen
  end
end
