# frozen_string_literal: true

RSpec.describe Craigslist::API::JsonTransport do
  subject(:client) { build_client }

  let(:status_url) { "#{bapi}/postings/7123456780/status" }

  describe "authentication" do
    it "exchanges credentials for a token before the first call" do
      token = stub_token
      stub_request(:get, status_url).to_return(json_response("status" => "active"))

      client.postings.status("7123456780")

      expect(token).to have_been_requested.once
    end

    it "sends the client_id and password as HTTP Basic on the token request" do
      encoded = ["bulk@example.com;4242:s3cret"].pack("m0")
      token = stub_request(:post, token_url)
        .with(headers: {"Authorization" => "Basic #{encoded}"})
        .to_return(status: 200, headers: json_headers,
          body: JSON.dump("access_token" => "t", "expires_in" => 3600))
      stub_request(:get, status_url).to_return(json_response("status" => "active"))

      client.postings.status("7123456780")

      expect(token).to have_been_requested
    end

    it "requests the configured scopes with the client_credentials grant" do
      token = stub_request(:post, token_url)
        .with(body: hash_including("grant_type" => "client_credentials"))
        .to_return(status: 200, headers: json_headers,
          body: JSON.dump("access_token" => "t", "expires_in" => 3600))
      stub_request(:get, status_url).to_return(json_response("status" => "active"))

      client.postings.status("7123456780")

      expect(token).to have_been_requested
    end

    it "presents the token as a bearer credential" do
      stub_token(value: "tok-42")
      call = stub_request(:get, status_url)
        .with(headers: {"Authorization" => "Bearer tok-42"})
        .to_return(json_response("status" => "active"))

      client.postings.status("7123456780")

      expect(call).to have_been_requested
    end

    it "reuses a live token across calls rather than re-authenticating" do
      token = stub_token
      stub_request(:get, status_url).to_return(json_response("status" => "active"))

      3.times { client.postings.status("7123456780") }

      expect(token).to have_been_requested.once
    end

    it "re-authenticates once when a token is rejected early" do
      token = stub_token
      call = stub_request(:get, status_url)
        .to_return({status: 401, headers: json_headers, body: "{}"})
        .then.to_return(json_response("status" => "active"))

      expect(client.postings.status("7123456780")).to eq("active")
      expect(token).to have_been_requested.twice
      expect(call).to have_been_requested.twice
    end

    it "gives up after a single retry rather than looping" do
      stub_token
      stub_request(:get, status_url)
        .to_return(status: 401, headers: json_headers, body: "{}")

      expect { client.postings.status("7123456780") }
        .to raise_error(Craigslist::API::AuthenticationError)
    end

    it "raises when the token endpoint rejects the credentials" do
      stub_token(status: 401)

      expect { client.postings.status("7123456780") }
        .to raise_error(Craigslist::API::AuthenticationError, /token request failed/)
    end
  end

  describe "in-band errors" do
    before { stub_token }

    it "raises APIError when a 200 carries a populated errors array" do
      stub_request(:get, status_url).to_return(
        json_envelope_response(nil, errors: [{"code" => 0, "message" => "posting 7123456780 not found"}])
      )

      expect { client.postings.status("7123456780") }
        .to raise_error(Craigslist::API::APIError, /posting 7123456780 not found/)
    end

    it "attaches the structured errors to the exception" do
      stub_request(:get, status_url).to_return(
        json_envelope_response(nil, errors: [{"code" => 7, "message" => "nope"}])
      )

      begin
        client.postings.status("7123456780")
      rescue Craigslist::API::APIError => e
        expect(e.api_errors).to eq([{"code" => 7, "message" => "nope"}])
      end
    end
  end

  describe "status mapping" do
    before { stub_token }

    {
      400 => Craigslist::API::RequestError,
      403 => Craigslist::API::AuthenticationError,
      404 => Craigslist::API::NotFoundError,
      429 => Craigslist::API::RateLimitError,
      500 => Craigslist::API::ServerError,
      503 => Craigslist::API::ServerError
    }.each do |status, error_class|
      it "raises #{error_class} on #{status}" do
        stub_request(:get, status_url).to_return(status: status, body: "")

        expect { client.postings.status("7123456780") }.to raise_error(error_class)
      end
    end
  end

  describe "account messages" do
    before { stub_token }

    it "surfaces notices attached to the last response" do
      stub_request(:get, status_url).to_return(
        json_envelope_response({"status" => "active"},
          account_messages: [{"messageId" => "m1", "message" => "System maintenance tonight."}])
      )

      client.postings.status("7123456780")

      expect(client.account_messages)
        .to eq([{"messageId" => "m1", "message" => "System maintenance tonight."}])
    end
  end

  it "raises ParseError when a success response is not JSON" do
    stub_token
    stub_request(:get, status_url)
      .to_return(status: 200, headers: json_headers, body: "<html>nope</html>")

    expect { client.postings.status("7123456780") }
      .to raise_error(Craigslist::API::ParseError)
  end
end
