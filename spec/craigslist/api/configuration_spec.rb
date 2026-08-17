# frozen_string_literal: true

RSpec.describe Craigslist::API::Configuration do
  describe "validation" do
    it "requires an email" do
      expect { build_config(email: "") }
        .to raise_error(Craigslist::API::ConfigurationError, /email is required/)
    end

    it "requires a password" do
      expect { build_config(password: nil) }
        .to raise_error(Craigslist::API::ConfigurationError, /password is required/)
    end

    it "requires an account id" do
      expect { build_config(account_id: "  ") }
        .to raise_error(Craigslist::API::ConfigurationError, /account_id is required/)
    end
  end

  it "is frozen so nothing can mutate it at request time" do
    expect(build_config).to be_frozen
  end

  describe "#client_id" do
    it "joins the email and account id with a semicolon" do
      expect(build_config.client_id).to eq("bulk@example.com;4242")
    end
  end

  describe "#basic_authorization" do
    it "base64-encodes client_id:password on a single line" do
      encoded = ["bulk@example.com;4242:s3cret"].pack("m0")

      expect(build_config.basic_authorization).to eq("Basic #{encoded}")
    end

    it "produces no line breaks, which would corrupt the header" do
      expect(build_config.basic_authorization).not_to include("\n")
    end
  end

  describe "#inspect" do
    it "redacts the password so it cannot leak through logs or backtraces" do
      output = build_config.inspect

      expect(output).to include("[FILTERED]")
      expect(output).not_to include("s3cret")
    end
  end

  it "exposes the two RSS endpoints" do
    config = build_config

    expect(config.validate_url).to eq("https://post.craigslist.org/bulk-rss/validate")
    expect(config.post_url).to eq("https://post.craigslist.org/bulk-rss/post")
  end

  it "coerces a numeric account id to a string" do
    expect(build_config(account_id: 99).account_id).to eq("99")
  end

  it "accepts overridden hosts for testing against a stub server" do
    config = build_config(bapi_host: "https://example.test")

    expect(config.bapi_host).to eq("https://example.test")
  end
end
