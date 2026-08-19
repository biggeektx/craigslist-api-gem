# frozen_string_literal: true

RSpec.describe Craigslist::API::Resources::Postings do
  subject(:postings) { build_client.postings }

  let(:id) { "7123456780" }

  before { stub_token }

  it "reads the status" do
    stub_request(:get, "#{bapi}/postings/#{id}/status")
      .to_return(json_response("status" => "active"))

    expect(postings.status(id)).to eq("active")
  end

  it "reads the body" do
    stub_request(:get, "#{bapi}/postings/#{id}/body")
      .to_return(json_response("body" => "The posting body"))

    expect(postings.body(id)).to eq("The posting body")
  end

  it "form-encodes a body update, since writes are not JSON" do
    stub = stub_request(:put, "#{bapi}/postings/#{id}/body")
      .with(
        body: {"body" => "new text"},
        headers: {"Content-Type" => "application/x-www-form-urlencoded"}
      )
      .to_return(json_response("body" => "new text", "message" => "posting body updated successfully"))

    expect(postings.update_body(id, "new text")).to eq("new text")
    expect(stub).to have_been_requested
  end

  it "reads the price" do
    stub_request(:get, "#{bapi}/postings/#{id}/price")
      .to_return(json_response("price" => 99))

    expect(postings.price(id)).to eq(99)
  end

  it "updates the price" do
    stub = stub_request(:put, "#{bapi}/postings/#{id}/price")
      .with(body: {"price" => "4200"})
      .to_return(json_response("price" => 4200, "message" => "price changed successfully"))

    expect(postings.update_price(id, 4200)).to eq(4200)
    expect(stub).to have_been_requested
  end

  it "reads remuneration" do
    stub_request(:get, "#{bapi}/postings/#{id}/remuneration")
      .to_return(json_response("remuneration" => "$19.95/hr plus tips"))

    expect(postings.remuneration(id)).to eq("$19.95/hr plus tips")
  end

  it "updates remuneration" do
    stub = stub_request(:put, "#{bapi}/postings/#{id}/remuneration")
      .with(body: {"remuneration" => "$25/hr"})
      .to_return(json_response("remuneration" => "$25/hr"))

    expect(postings.update_remuneration(id, "$25/hr")).to eq("$25/hr")
    expect(stub).to have_been_requested
  end

  it "deletes" do
    stub = stub_request(:delete, "#{bapi}/postings/#{id}")
      .to_return(json_response("message" => "posting #{id} has been deleted"))

    expect(postings.delete(id)).to be(true)
    expect(stub).to have_been_requested
  end

  it "undeletes" do
    stub = stub_request(:put, "#{bapi}/postings/#{id}/undelete")
      .to_return(json_response("message" => "posting #{id} has been undeleted"))

    expect(postings.undelete(id)).to be(true)
    expect(stub).to have_been_requested
  end

  it "maps a ZIP code to an area and its subarea" do
    stub_request(:get, "#{bapi}/posting/zip/02134/area").to_return(json_response(
      "area" => {"abbreviation" => "bos", "description" => "boston"},
      "subarea" => {"abbreviation" => "gbs", "description" => "boston/cambridge/brookline"}
    ))

    place = postings.area_for_zip("02134")

    expect(place.area).to eq("bos")
    expect(place.subarea).to eq("gbs")
    expect(place.to_h).to eq({area: "bos", subarea: "gbs"})
  end

  it "reports no subarea for an area that has none" do
    stub_request(:get, "#{bapi}/posting/zip/15314/area").to_return(json_response(
      "area" => {"abbreviation" => "pit", "description" => "pittsburgh, PA"}
    ))

    place = postings.area_for_zip("15314")

    expect(place).not_to be_subarea
    expect(place.to_h).to eq({area: "pit"})
  end

  it "raises NotFoundError for an unknown posting" do
    stub_request(:get, "#{bapi}/postings/nope/status").to_return(status: 404, body: "")

    expect { postings.status("nope") }.to raise_error(Craigslist::API::NotFoundError)
  end
end
