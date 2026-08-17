# frozen_string_literal: true

RSpec.describe Craigslist::API::ResultSet do
  def result(key, status, **rest)
    Craigslist::API::Result.new(key: key, status: status, **rest)
  end

  subject(:set) do
    described_class.new(
      results: [
        result("a", Craigslist::API::Result::POSTED, posting_id: "111"),
        result("b", Craigslist::API::Result::FAILED, explanation: "boom"),
        result("c", Craigslist::API::Result::POSTED, posting_id: "333", warnings: ["odd tag"])
      ],
      upload_id: "UPLOAD-1"
    )
  end

  it "is enumerable" do
    expect(set.map(&:key)).to eq(%w[a b c])
  end

  it "looks results up by the key you submitted" do
    expect(set["b"].explanation).to eq("boom")
  end

  it "returns nil for an unknown key" do
    expect(set["nope"]).to be_nil
  end

  it "partitions successes and failures" do
    expect(set.successful.map(&:key)).to eq(%w[a c])
    expect(set.failed.map(&:key)).to eq(["b"])
  end

  it "surfaces results carrying warnings, which are easy to miss on a success" do
    expect(set.warned.map(&:key)).to eq(["c"])
  end

  it "collects the created posting ids" do
    expect(set.posting_ids).to eq(%w[111 333])
  end

  it "reports partial failure" do
    expect(set).to be_any_failures
    expect(set).not_to be_all_successful
  end

  it "reports a clean batch as fully successful" do
    clean = described_class.new(results: [result("a", Craigslist::API::Result::VALID)])

    expect(clean).to be_all_successful
    expect(clean).not_to be_any_failures
  end

  it "is frozen" do
    expect(set).to be_frozen
  end
end
