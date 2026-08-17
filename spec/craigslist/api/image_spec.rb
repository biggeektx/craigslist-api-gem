# frozen_string_literal: true

require "tempfile"
require "stringio"

RSpec.describe Craigslist::API::Image do
  describe ".from_data" do
    it "base64-encodes raw bytes" do
      expect(described_class.from_data("jpegbytes").data).to eq(["jpegbytes"].pack("m"))
    end

    it "uses RFC 2045 wrapping, matching craigslist's own examples" do
      long = described_class.from_data("x" * 200).data

      expect(long).to include("\n")
    end
  end

  describe ".from_base64" do
    it "takes already-encoded data verbatim" do
      expect(described_class.from_base64("YWJj").data).to eq("YWJj")
    end
  end

  describe ".from_file" do
    it "reads and encodes the file" do
      file = Tempfile.new(["photo", ".jpg"])
      file.binmode
      file.write("jpegbytes")
      file.flush

      expect(described_class.from_file(file.path).data).to eq(["jpegbytes"].pack("m"))
    ensure
      file&.close!
    end

    it "raises ValidationError for a missing file" do
      expect { described_class.from_file("/no/such/file.jpg") }
        .to raise_error(Craigslist::API::ValidationError, /could not read image/)
    end
  end

  describe ".from_io" do
    it "reads the stream" do
      expect(described_class.from_io(StringIO.new("jpegbytes")).data)
        .to eq(["jpegbytes"].pack("m"))
    end
  end

  describe ".wrap" do
    it "passes an existing Image through" do
      original = described_class.from_data("bytes")

      expect(described_class.wrap(original)).to equal(original)
    end

    it "reads an IO" do
      expect(described_class.wrap(StringIO.new("bytes"))).to be_a(described_class)
    end

    it "rejects a type it cannot interpret" do
      expect { described_class.wrap(42) }
        .to raise_error(Craigslist::API::ValidationError, /cannot build an image/)
    end
  end

  describe "#with_default_position" do
    it "assigns a position when none was set" do
      expect(described_class.from_data("x").with_default_position(3).position).to eq(3)
    end

    it "leaves an explicit position alone" do
      pinned = described_class.from_data("x", position: 9)

      expect(pinned.with_default_position(3).position).to eq(9)
    end
  end

  it "is frozen" do
    expect(described_class.from_data("x")).to be_frozen
  end
end
