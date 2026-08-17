# frozen_string_literal: true

require "rexml/document"

RSpec.describe Craigslist::API::Serializer do
  subject(:serializer) { described_class.new(build_config) }

  def document_for(*postings)
    REXML::Document.new(serializer.serialize(postings))
  end

  def item_in(document)
    document.root.get_elements("item").first
  end

  it "declares the three namespaces the interface expects" do
    root = document_for(build_posting).root

    expect(root.attributes["xmlns"]).to eq("http://purl.org/rss/1.0/")
    expect(root.attributes["xmlns:rdf"]).to eq("http://www.w3.org/1999/02/22-rdf-syntax-ns#")
    expect(root.attributes["xmlns:cl"]).to eq("http://www.craigslist.org/about/cl-bulk-ns/1.0")
  end

  it "puts credentials in cl:auth" do
    auth = document_for(build_posting).root.get_elements("channel/cl:auth").first

    expect(auth.attributes["username"]).to eq("bulk@example.com")
    expect(auth.attributes["password"]).to eq("s3cret")
    expect(auth.attributes["accountID"]).to eq("4242")
  end

  it "lists every posting key in the channel manifest" do
    document = document_for(build_posting(key: "a"), build_posting(key: "b"))
    keys = document.root.get_elements("channel/items/rdf:li")
      .map { |li| li.attributes["rdf:resource"] }

    expect(keys).to eq(%w[a b])
  end

  it "matches each item's rdf:about to its manifest entry" do
    document = document_for(build_posting(key: "listing-9"))

    expect(item_in(document).attributes["rdf:about"]).to eq("listing-9")
  end

  describe "escaping" do
    it "escapes markup in the title" do
      xml = serializer.serialize([build_posting(title: "Fish & <Chips>")])

      expect(xml).to include("Fish &amp; &lt;Chips&gt;")
    end

    it "wraps the description in CDATA so markup survives verbatim" do
      xml = serializer.serialize([build_posting(description: "<b>bold</b> & raw")])

      expect(xml).to include("<![CDATA[<b>bold</b> & raw]]>")
    end

    it "splits CDATA around a literal ]]> instead of corrupting the document" do
      body = "before ]]> after"
      document = document_for(build_posting(description: body))
      description = item_in(document).get_elements("description").first

      expect(description.texts.map(&:value).join).to eq(body)
    end
  end

  describe "attribute groups" do
    it "translates Ruby booleans to the 0/1 the interface expects" do
      document = document_for(
        build_posting(housing_basics: {is_furnished: true, no_smoking: false})
      )
      group = item_in(document).get_elements("cl:housing_basics").first

      expect(group.attributes["is_furnished"]).to eq("1")
      expect(group.attributes["no_smoking"]).to eq("0")
    end

    it "omits empty groups entirely" do
      xml = serializer.serialize([build_posting])

      expect(xml).not_to include("cl:housing_basics")
    end

    it "renames location keys to the camelCase the wire format uses" do
      document = document_for(
        build_posting(location: {postal: "94110", cross_street1: "24th", cross_street2: "Mission"})
      )
      location = item_in(document).get_elements("cl:mapLocation").first

      expect(location.attributes["crossStreet1"]).to eq("24th")
      expect(location.attributes["crossStreet2"]).to eq("Mission")
    end

    it "renames broker keys" do
      document = document_for(build_posting(broker: {company_name: "Acme", fee_disclosure: "1 month"}))
      broker = item_in(document).get_elements("cl:brokerInfo").first

      expect(broker.attributes["companyName"]).to eq("Acme")
      expect(broker.attributes["feeDisclosure"]).to eq("1 month")
    end
  end

  describe "reply email" do
    it "carries privacy and alternate contact info as attributes" do
      document = document_for(
        build_posting(reply_email: "me@example.com", reply_privacy: :public, other_contact_info: "555-1212")
      )
      reply = item_in(document).get_elements("cl:replyEmail").first

      expect(reply.text).to eq("me@example.com")
      expect(reply.attributes["privacy"]).to eq("P")
      expect(reply.attributes["otherContactInfo"]).to eq("555-1212")
    end

    it "is omitted when no address is given" do
      xml = serializer.serialize([build_posting(reply_email: nil)])

      expect(xml).not_to include("cl:replyEmail")
    end
  end

  describe "images" do
    it "emits base64 data with its position" do
      posting = build_posting(images: [Craigslist::API::Image.from_data("jpegbytes")])
      image = item_in(document_for(posting)).get_elements("cl:image").first

      expect(image.attributes["position"]).to eq("0")
      expect(image.texts.map(&:value).join.strip).to eq(["jpegbytes"].pack("m").strip)
    end
  end

  it "omits optional elements that were never set" do
    xml = serializer.serialize([build_posting(subarea: nil, neighborhood: nil, po_number: nil)])

    expect(xml).not_to include("cl:subarea")
    expect(xml).not_to include("cl:neighborhood")
    expect(xml).not_to include("cl:PONumber")
  end

  it "writes into a provided IO rather than allocating a new string" do
    buffer = +""
    serializer.serialize([build_posting], io: buffer)

    expect(buffer).to include("<rdf:RDF")
  end

  it "produces a well-formed document for a multi-posting batch" do
    xml = serializer.serialize([build_posting(key: "a"), build_posting(key: "b")])

    expect { REXML::Document.new(xml) }.not_to raise_error
    expect(REXML::Document.new(xml).root.get_elements("item").size).to eq(2)
  end
end
