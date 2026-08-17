# frozen_string_literal: true

require "tempfile"

RSpec.describe Craigslist::API::Resources::Images do
  subject(:images) { build_client.images }

  let(:id) { "7123456780" }
  let(:images_url) { "#{bapi}/postings/#{id}/images" }

  before { stub_token }

  describe "#list" do
    it "wraps each entry in an ImageInfo" do
      stub_request(:get, images_url).to_return(json_response(
        "imageInfo" => [
          {"id" => "4:00101_b1ztTgNtBAU", "filename" => "/one.gif", "format" => "GIF",
           "height" => 570, "width" => 1201, "position" => 0}
        ]
      ))

      info = images.list(id).first

      expect(info.id).to eq("4:00101_b1ztTgNtBAU")
      expect(info.format).to eq("GIF")
      expect(info.width).to eq(1201)
      expect(info.position).to eq(0)
    end

    it "returns an empty array when the posting has no images" do
      stub_request(:get, images_url).to_return(json_response({}))

      expect(images.list(id)).to eq([])
    end
  end

  describe "#upload" do
    let(:file) do
      Tempfile.new(["photo", ".jpg"]).tap do |f|
        f.binmode
        f.write("jpegbytes")
        f.flush
      end
    end

    after { file.close! }

    it "PUTs multipart form data" do
      stub = stub_request(:put, images_url)
        .with(headers: {"Content-Type" => %r{\Amultipart/form-data}})
        .to_return(json_response(
          "imageInfo" => {"id" => "4:00000_new", "position" => 2, "format" => "JPEG"}
        ))

      info = images.upload(id, file.path)

      expect(info.id).to eq("4:00000_new")
      expect(stub).to have_been_requested
    end

    # WebMock cannot match bodies for multipart/form-data, so positioning is
    # asserted at the transport boundary. The multipart encoding itself is
    # Faraday's responsibility, not ours.
    describe "positioning" do
      let(:transport) { instance_double(Craigslist::API::JsonTransport) }
      let(:resource) { described_class.new(transport) }
      let(:envelope) { Craigslist::API::Envelope.new(data: {"imageInfo" => {"id" => "x"}}) }

      before { allow(transport).to receive(:upload).and_return(envelope) }

      it "sends insert_position when asked to insert" do
        resource.upload(id, file.path, insert_position: 7)

        expect(transport).to have_received(:upload).with(
          "/bulkpost/v1/postings/#{id}/images",
          part: instance_of(Faraday::Multipart::FilePart),
          fields: {"insert_position" => "7"}
        )
      end

      it "sends replace_position when asked to replace" do
        resource.upload(id, file.path, replace_position: 3)

        expect(transport).to have_received(:upload).with(
          "/bulkpost/v1/postings/#{id}/images",
          part: instance_of(Faraday::Multipart::FilePart),
          fields: {"replace_position" => "3"}
        )
      end

      it "sends no position fields when appending" do
        resource.upload(id, file.path)

        expect(transport).to have_received(:upload).with(
          "/bulkpost/v1/postings/#{id}/images",
          part: instance_of(Faraday::Multipart::FilePart),
          fields: {}
        )
      end
    end

    it "refuses both positions at once, which the API cannot honour" do
      expect { images.upload(id, file.path, insert_position: 1, replace_position: 2) }
        .to raise_error(Craigslist::API::ValidationError, /not both/)
    end

    it "rejects a source that is neither a path nor an IO" do
      expect { images.upload(id, 42) }
        .to raise_error(Craigslist::API::ValidationError, /pass a path or an IO/)
    end
  end

  describe "#reorder" do
    it "POSTs a comma-separated id list" do
      stub = stub_request(:post, images_url)
        .with(body: {"imageIdList" => "a,b,c"})
        .to_return(json_response("message" => "image order is now a,b,c"))

      expect(images.reorder(id, %w[a b c])).to be(true)
      expect(stub).to have_been_requested
    end
  end

  describe "#remove" do
    it "percent-encodes the colon in an image id" do
      stub = stub_request(:delete, "#{bapi}/postings/#{id}/images/4%3A00808_abc")
        .to_return(json_response("message" => "removed"))

      expect(images.remove(id, "4:00808_abc")).to be(true)
      expect(stub).to have_been_requested
    end
  end
end
