# frozen_string_literal: true

RSpec.describe Craigslist::API::Client do
  subject(:client) { build_client }

  it "is constructible through the module shorthand" do
    expect(Craigslist::API.new(**ClientHelpers::CREDENTIALS)).to be_a(described_class)
  end

  it "raises on missing credentials before any request is attempted" do
    expect { described_class.new(email: "a@b.com", password: "", account_id: 1) }
      .to raise_error(Craigslist::API::ConfigurationError)
  end

  it "keeps the password out of inspect output" do
    expect(client.inspect).not_to include("s3cret")
  end

  describe "#validate" do
    it "posts the RSS document to the validate endpoint" do
      stub_request(:post, validate_url)
        .to_return(status: 200, headers: xml_headers, body: fixture("validate_response.xml"))

      results = client.validate(build_posting(key: "NYCBrokerHousingSample1"))

      expect(results["NYCBrokerHousingSample1"]).to be_valid
    end

    it "sends text/xml, as the protocol specifies" do
      stub = stub_request(:post, validate_url)
        .with(headers: {"Content-Type" => "text/xml; charset=utf-8"})
        .to_return(status: 200, headers: xml_headers, body: fixture("validate_response.xml"))

      client.validate(build_posting)

      expect(stub).to have_been_requested
    end

    it "sends the credentials inside the document body" do
      stub = stub_request(:post, validate_url)
        .with(body: /accountID='4242'/)
        .to_return(status: 200, headers: xml_headers, body: fixture("validate_response.xml"))

      client.validate(build_posting)

      expect(stub).to have_been_requested
    end

    it "accepts a single posting as well as an array" do
      stub_request(:post, validate_url)
        .to_return(status: 200, headers: xml_headers, body: fixture("validate_response.xml"))

      expect { client.validate(build_posting) }.not_to raise_error
    end
  end

  describe "#post" do
    before do
      stub_request(:post, post_url)
        .to_return(status: 200, headers: xml_headers, body: fixture("post_response.xml"))
    end

    it "returns results rather than raising when some postings fail" do
      results = client.post([build_posting(key: "a"), build_posting(key: "b")])

      expect(results.failed.size).to eq(1)
      expect(results.successful.size).to eq(1)
    end

    it "exposes the upload id for the batch" do
      expect(client.post(build_posting).upload_id)
        .to eq("FD95E9A8-E192-11E6-A34F-C577977E6A6B")
    end
  end

  describe "bulk submission failures" do
    it "raises AuthenticationError on 403" do
      stub_request(:post, post_url)
        .to_return(status: 403, body: "This user account is not granted bulk post access")

      expect { client.post(build_posting) }
        .to raise_error(Craigslist::API::AuthenticationError, /not granted bulk post access/)
    end

    it "raises RequestError on 415, which signals unparseable RSS" do
      stub_request(:post, post_url).to_return(status: 415, body: "Failed to parse RSS")

      expect { client.post(build_posting) }
        .to raise_error(Craigslist::API::RequestError, /Failed to parse RSS/)
    end

    it "raises ServerError on 500" do
      stub_request(:post, post_url).to_return(status: 500, body: "boom")

      expect { client.post(build_posting) }.to raise_error(Craigslist::API::ServerError)
    end

    it "carries the status and body on the error for inspection" do
      stub_request(:post, post_url).to_return(status: 415, body: "Failed to parse RSS")

      begin
        client.post(build_posting)
      rescue Craigslist::API::RequestError => e
        expect(e.status).to eq(415)
        expect(e.body).to include("Failed to parse RSS")
      end
    end

    it "translates a connection failure" do
      stub_request(:post, post_url).to_raise(Faraday::ConnectionFailed.new("refused"))

      expect { client.post(build_posting) }
        .to raise_error(Craigslist::API::ConnectionError, /connection failed/)
    end

    it "translates a timeout" do
      stub_request(:post, post_url).to_timeout

      # TimeoutError subclasses ConnectionError; which of the two surfaces
      # depends on whether the adapter saw an open or a read timeout.
      expect { client.post(build_posting) }.to raise_error(Craigslist::API::ConnectionError)
    end
  end

  describe "local validation" do
    it "refuses an empty batch without making a request" do
      expect { client.post([]) }
        .to raise_error(Craigslist::API::ValidationError, /at least one posting/)
    end

    it "refuses duplicate keys, which would lose a result" do
      expect { client.post([build_posting(key: "dupe"), build_posting(key: "dupe")]) }
        .to raise_error(Craigslist::API::ValidationError, /duplicate posting keys/)
    end
  end

  describe "#posting" do
    it "returns a handle for a live posting" do
      handle = client.posting("7123456780")

      expect(handle).to be_a(Craigslist::API::PostingHandle)
      expect(handle.id).to eq("7123456780")
    end
  end

  it "exposes the resource groups" do
    expect(client.postings).to be_a(Craigslist::API::Resources::Postings)
    expect(client.images).to be_a(Craigslist::API::Resources::Images)
    expect(client.billing).to be_a(Craigslist::API::Resources::Billing)
    expect(client.account).to be_a(Craigslist::API::Resources::Account)
    expect(client.reference).to be_a(Craigslist::API::Reference)
  end
end
