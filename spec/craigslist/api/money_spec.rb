# frozen_string_literal: true

RSpec.describe Craigslist::API::Money do
  subject(:money) { described_class.new(amount: 100_000, currency: "USD", exponent: 2) }

  it "scales minor units by the exponent" do
    expect(money.to_r).to eq(Rational(1000))
    expect(money.to_f).to eq(1000.0)
  end

  it "formats with the currency" do
    expect(money.to_s).to eq("1000.00 USD")
  end

  it "scales exactly, without float drift" do
    expect(described_class.new(amount: 7, exponent: 2).to_r).to eq(Rational(7, 100))
  end

  it "builds from the API payload" do
    built = described_class.from("amount" => 300, "currency" => "USD", "exponent" => 2)

    expect(built.to_s).to eq("3.00 USD")
  end

  it "returns nil when there is no payload" do
    expect(described_class.from(nil)).to be_nil
  end

  it "defaults to USD with two decimal places" do
    built = described_class.from("amount" => 500)

    expect(built.currency).to eq("USD")
    expect(built.exponent).to eq(2)
  end

  it "compares by value" do
    expect(money).to eq(described_class.new(amount: 100_000, currency: "USD", exponent: 2))
    expect(money).not_to eq(described_class.new(amount: 1, currency: "USD", exponent: 2))
  end

  it "hashes by value so it can key a Hash" do
    other = described_class.new(amount: 100_000, currency: "USD", exponent: 2)

    expect({money => :ok}[other]).to eq(:ok)
  end

  it "is frozen" do
    expect(money).to be_frozen
  end
end
