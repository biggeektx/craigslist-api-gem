# frozen_string_literal: true

RSpec.describe Craigslist::API::ResponseParser do
  describe "a validation response" do
    subject(:results) { described_class.parse(fixture("validate_response.xml")) }

    it "returns one result per submitted posting" do
      expect(results.size).to eq(2)
    end

    it "reads the VALID status" do
      expect(results["NYCBrokerHousingSample1"]).to be_valid
    end

    it "treats VALID as success" do
      expect(results["NYCBrokerHousingSample1"]).to be_success
    end

    it "reads NOT_VALID with its explanation" do
      result = results["NYCBrokerHousingSample2"]

      expect(result).to be_not_valid
      expect(result).to be_failure
      expect(result.explanation).to eq("Missing required field: area.")
    end

    it "collects warnings, which can accompany either outcome" do
      expect(results["NYCBrokerHousingSample2"].warnings)
        .to eq(["unexpected element cl:bogus ignored"])
    end

    it "extracts CDATA preview HTML" do
      expect(results["NYCBrokerHousingSample1"].preview_html)
        .to include("<p>HTML preview of posting will appear here.</p>")
    end

    it "has no upload id, which only post mode returns" do
      expect(results.upload_id).to be_nil
    end
  end

  describe "a posting response" do
    subject(:results) { described_class.parse(fixture("post_response.xml")) }

    it "extracts the upload id from the channel description" do
      expect(results.upload_id).to eq("FD95E9A8-E192-11E6-A34F-C577977E6A6B")
    end

    it "reads the new posting id" do
      expect(results["NYCBrokerHousingSample1"].posting_id).to eq("159144091")
    end

    it "strips the whitespace craigslist wraps around URLs" do
      result = results["NYCBrokerHousingSample1"]

      expect(result.manage_url).to eq("https://post.craigslist.org/manage/159144091/to6s1")
      expect(result.view_url)
        .to eq("https://newyork.craigslist.org/mnh/prk/d/parking-spot-for-rent-at-east/159144091.html")
    end

    it "recognises INSUFFICIENT_BLOCKS as a failure" do
      result = results["NYCBrokerHousingSample2"]

      expect(result).to be_insufficient_blocks
      expect(result).to be_failure
    end

    it "reports the batch as partially failed" do
      expect(results).not_to be_all_successful
      expect(results.failed.map(&:key)).to eq(["NYCBrokerHousingSample2"])
    end

    it "collects ids of postings that were actually created" do
      expect(results.posting_ids).to eq(["159144091"])
    end
  end

  describe "malformed input" do
    it "raises ParseError rather than leaking REXML's exception" do
      expect { described_class.parse("<rdf:RDF><unclosed>") }
        .to raise_error(Craigslist::API::ParseError, /could not parse/)
    end

    it "raises ParseError on an empty body" do
      expect { described_class.parse("") }
        .to raise_error(Craigslist::API::ParseError)
    end
  end
end
