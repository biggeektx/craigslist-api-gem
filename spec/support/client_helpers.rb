# frozen_string_literal: true

require "json"

# Shared construction and stubbing helpers.
module ClientHelpers
  CREDENTIALS = {
    email: "bulk@example.com",
    password: "s3cret",
    account_id: 4242
  }.freeze

  TOKEN_URL = "https://bapi.craigslist.org/bulkpost/oauth/access-token"
  BAPI = "https://bapi.craigslist.org/bulkpost/v1"
  VALIDATE_URL = "https://post.craigslist.org/bulk-rss/validate"
  POST_URL = "https://post.craigslist.org/bulk-rss/post"

  # Exposed as methods rather than referenced as constants: Ruby resolves bare
  # constants lexically, so an example block cannot see a constant that merely
  # arrived via include.
  def token_url = TOKEN_URL

  def bapi = BAPI

  def validate_url = VALIDATE_URL

  def post_url = POST_URL

  def build_config(**overrides)
    Craigslist::API::Configuration.new(**CREDENTIALS, **overrides)
  end

  def build_client(**overrides)
    Craigslist::API::Client.new(**CREDENTIALS, **overrides)
  end

  # Every JSON API call needs a token first, so most specs start here.
  def stub_token(value: "test-token", expires_in: 3600, status: 200)
    body =
      if status == 200
        JSON.dump(
          "access_token" => value,
          "expires_in" => expires_in,
          "token_type" => "Bearer",
          "scopes" => [Craigslist::API::Configuration::DEFAULT_SCOPES.join(" ")]
        )
      else
        JSON.dump("error" => "invalid_client")
      end

    stub_request(:post, TOKEN_URL)
      .to_return(status: status, headers: json_headers, body: body)
  end

  # Wraps a payload in the envelope every JSON endpoint returns.
  def envelope(data, errors: [], account_messages: [])
    JSON.dump(
      "apiVersion" => 1,
      "data" => data,
      "errors" => errors,
      "accountMessages" => account_messages
    )
  end

  # Takes no keyword arguments on purpose. Ruby 3 routes a brace-less hash at
  # the call site into keywords whenever the method accepts any, which would
  # make the common `json_response("status" => "active")` an arity error.
  def json_response(data)
    {status: 200, headers: json_headers, body: envelope(data)}
  end

  # For the cases that need to set the envelope's errors or notices.
  def json_envelope_response(data, status: 200, errors: [], account_messages: [])
    {
      status: status,
      headers: json_headers,
      body: envelope(data, errors: errors, account_messages: account_messages)
    }
  end

  def json_headers
    {"Content-Type" => "application/json"}
  end

  def xml_headers
    {"Content-Type" => "text/xml"}
  end

  def build_posting(**overrides)
    defaults = {
      key: "listing-1",
      title: "1998 Toyota Hilux",
      description: "Runs great.",
      category: "ctd",
      area: "sfo",
      location: {postal: "94110"}
    }

    Craigslist::API::Posting.new(**defaults.merge(overrides))
  end
end
