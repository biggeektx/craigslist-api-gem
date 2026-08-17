# frozen_string_literal: true

RSpec.describe Craigslist::API::Resources::Billing do
  subject(:billing) { build_client.billing }

  before { stub_token }

  describe "#credit" do
    it "converts each figure from minor units" do
      stub_request(:get, "#{bapi}/account/billing/credit").to_return(json_response(
        "creditLine" => {"amount" => 100_000, "currency" => "USD", "exponent" => 2},
        "creditRemaining" => {"amount" => 300, "currency" => "USD", "exponent" => 2},
        "creditUsed" => {"amount" => 700, "currency" => "USD", "exponent" => 2}
      ))

      credit = billing.credit

      expect(credit.credit_line.to_s).to eq("1000.00 USD")
      expect(credit.remaining.to_f).to eq(3.0)
      expect(credit.used.to_f).to eq(7.0)
    end
  end

  describe "#posting_blocks" do
    it "wraps each balance" do
      stub_request(:get, "#{bapi}/account/billing/posting-block-balances").to_return(json_response(
        [
          {"area" => "htf", "productClass" => "CAR",
           "productName" => "hartford cars & trucks - by dealer block", "remainingPosts" => 2},
          {"area" => "fre", "productClass" => "JOB",
           "productName" => "fresno / madera job posting block", "remainingPosts" => 3}
        ]
      ))

      blocks = billing.posting_blocks

      expect(blocks.map(&:area)).to eq(%w[htf fre])
      expect(blocks.first.product_class).to eq("CAR")
      expect(blocks.first.remaining_posts).to eq(2)
    end
  end

  describe "#pricing" do
    it "builds the area and category path and returns Money" do
      stub = stub_request(:get, "#{bapi}/account/billing/current-pricing/area/sfo/category/ofc")
        .to_return(json_response(
          "area" => "sfo", "cat" => "ofc",
          "currentPricing" => {"amount" => 100_000, "currency" => "USD", "exponent" => 2}
        ))

      expect(billing.pricing(area: "sfo", category: "ofc").to_s).to eq("1000.00 USD")
      expect(stub).to have_been_requested
    end
  end

  describe "#create_invoice" do
    it "returns the invoice ids as strings" do
      stub_request(:post, "#{bapi}/account/billing/make-invoice")
        .to_return(json_response("invoiceIDs" => %w[1234321 1234322]))

      expect(billing.create_invoice).to eq(%w[1234321 1234322])
    end
  end
end
