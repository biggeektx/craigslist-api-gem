# frozen_string_literal: true

RSpec.describe Craigslist::API::Reference do
  subject(:reference) { build_client.reference }

  let(:areas_url) { "https://reference.craigslist.org/Areas" }
  let(:categories_url) { "https://reference.craigslist.org/Categories" }

  let(:areas_payload) do
    [
      {"Abbreviation" => "sfo", "AreaID" => 1, "Country" => "US", "Description" => "SF bay area",
       "Hostname" => "sfbay", "Latitude" => 37.5, "Longitude" => -122.25, "Region" => "CA",
       "ShortDescription" => "SF bay area",
       "SubAreas" => [
         {"Abbreviation" => "sfc", "Description" => "city of san francisco",
          "ShortDescription" => "san francisco", "SubAreaID" => 1}
       ]},
      {"Abbreviation" => "abq", "AreaID" => 2, "Description" => "albuquerque", "SubAreas" => []}
    ]
  end

  let(:categories_payload) do
    [
      {"Abbreviation" => "apa", "CategoryID" => 1,
       "Description" => "apartments / housing for rent", "Type" => "H"},
      {"Abbreviation" => "prk", "CategoryID" => 2, "Description" => "parking & storage", "Type" => "H"}
    ]
  end

  it "needs no authentication" do
    stub_request(:get, areas_url).to_return(status: 200, headers: json_headers, body: JSON.dump(areas_payload))

    reference.areas

    expect(a_request(:post, token_url)).not_to have_been_made
  end

  it "returns bare arrays rather than the Bulkpost envelope" do
    stub_request(:get, areas_url).to_return(status: 200, headers: json_headers, body: JSON.dump(areas_payload))

    expect(reference.areas.map(&:abbreviation)).to eq(%w[sfo abq])
  end

  it "nests subareas" do
    stub_request(:get, areas_url).to_return(status: 200, headers: json_headers, body: JSON.dump(areas_payload))

    sfo = reference.area("sfo")

    expect(sfo).to be_subareas
    expect(sfo.subarea("sfc").description).to eq("city of san francisco")
  end

  it "reports areas without subareas" do
    stub_request(:get, areas_url).to_return(status: 200, headers: json_headers, body: JSON.dump(areas_payload))

    expect(reference.area("abq")).not_to be_subareas
  end

  it "memoizes, since the payload is large and effectively static" do
    stub = stub_request(:get, areas_url)
      .to_return(status: 200, headers: json_headers, body: JSON.dump(areas_payload))

    3.times { reference.areas }

    expect(stub).to have_been_requested.once
  end

  it "refetches after reload" do
    stub = stub_request(:get, areas_url)
      .to_return(status: 200, headers: json_headers, body: JSON.dump(areas_payload))

    reference.areas
    reference.reload
    reference.areas

    expect(stub).to have_been_requested.twice
  end

  it "loads categories" do
    stub_request(:get, categories_url)
      .to_return(status: 200, headers: json_headers, body: JSON.dump(categories_payload))

    expect(reference.category("apa").description).to eq("apartments / housing for rent")
  end

  it "flags categories bulk posting does not support" do
    stub_request(:get, categories_url)
      .to_return(status: 200, headers: json_headers, body: JSON.dump(categories_payload))

    expect(reference.category("prk")).to be_unsupported
    expect(reference.category("apa")).not_to be_unsupported
  end

  it "raises on a failed request" do
    stub_request(:get, areas_url).to_return(status: 500, body: "boom")

    expect { reference.areas }.to raise_error(Craigslist::API::ResponseError, /HTTP 500/)
  end

  it "raises ParseError on malformed JSON" do
    stub_request(:get, areas_url).to_return(status: 200, headers: json_headers, body: "not json")

    expect { reference.areas }.to raise_error(Craigslist::API::ParseError)
  end
end
