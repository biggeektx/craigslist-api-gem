# frozen_string_literal: true

RSpec.describe Craigslist::API::PostingHandle do
  subject(:posting) { build_client.posting(id) }

  let(:id) { "7123456780" }

  before { stub_token }

  it "reads status" do
    stub_request(:get, "#{bapi}/postings/#{id}/status").to_return(json_response("status" => "active"))

    expect(posting.status).to eq("active")
    expect(posting).to be_active
  end

  it "answers status predicates" do
    stub_request(:get, "#{bapi}/postings/#{id}/status").to_return(json_response("status" => "deleted"))

    expect(posting).to be_deleted
    expect(posting).not_to be_active
  end

  it "supports assignment for the body" do
    stub = stub_request(:put, "#{bapi}/postings/#{id}/body")
      .with(body: {"body" => "updated"})
      .to_return(json_response("body" => "updated"))

    posting.body = "updated"

    expect(stub).to have_been_requested
  end

  it "supports assignment for the price" do
    stub = stub_request(:put, "#{bapi}/postings/#{id}/price")
      .with(body: {"price" => "4200"})
      .to_return(json_response("price" => 4200))

    posting.price = 4200

    expect(stub).to have_been_requested
  end

  it "supports assignment for remuneration" do
    stub = stub_request(:put, "#{bapi}/postings/#{id}/remuneration")
      .with(body: {"remuneration" => "$30/hr"})
      .to_return(json_response("remuneration" => "$30/hr"))

    posting.remuneration = "$30/hr"

    expect(stub).to have_been_requested
  end

  it "deletes and undeletes" do
    delete = stub_request(:delete, "#{bapi}/postings/#{id}").to_return(json_response("message" => "ok"))
    undelete = stub_request(:put, "#{bapi}/postings/#{id}/undelete").to_return(json_response("message" => "ok"))

    posting.delete
    posting.undelete

    expect(delete).to have_been_requested
    expect(undelete).to have_been_requested
  end

  it "lists images" do
    stub_request(:get, "#{bapi}/postings/#{id}/images")
      .to_return(json_response("imageInfo" => [{"id" => "4:001", "position" => 0}]))

    expect(posting.images.map(&:id)).to eq(["4:001"])
  end

  it "reorders images" do
    stub = stub_request(:post, "#{bapi}/postings/#{id}/images")
      .with(body: {"imageIdList" => "b,a"})
      .to_return(json_response("message" => "ok"))

    posting.reorder_images(%w[b a])

    expect(stub).to have_been_requested
  end

  it "reads its own statistics" do
    stub_request(:get, "#{bapi}/account/stats/posting/#{id}")
      .to_return(json_response([{"views" => [[1_746_748_800, 9]]}]))

    expect(posting.stats.total_views).to eq(9)
  end

  it "holds no cached state, so it cannot go stale" do
    stub_request(:get, "#{bapi}/postings/#{id}/status")
      .to_return(json_response("status" => "pending"))
      .then.to_return(json_response("status" => "active"))

    expect(posting.status).to eq("pending")
    expect(posting.status).to eq("active")
  end
end
