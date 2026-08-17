# frozen_string_literal: true

RSpec.describe Craigslist::API::Posting do
  describe "required fields" do
    %i[key title description category area].each do |field|
      it "rejects a blank #{field}" do
        expect { build_posting(field => "") }
          .to raise_error(Craigslist::API::ValidationError, /#{field} is required/)
      end
    end

    it "reports every problem at once rather than only the first" do
      expect { build_posting(title: "", category: "") }
        .to raise_error(Craigslist::API::ValidationError) { |error|
          expect(error.errors).to include(/title is required/, /category is required/)
        }
    end
  end

  describe "location" do
    it "accepts a postal code alone" do
      expect { build_posting(location: {postal: "94110"}) }.not_to raise_error
    end

    it "accepts latitude and longitude without a postal code" do
      expect { build_posting(location: {latitude: 37.7, longitude: -122.4}) }
        .not_to raise_error
    end

    it "rejects a location with neither" do
      expect { build_posting(location: {city: "San Francisco"}) }
        .to raise_error(Craigslist::API::ValidationError, /:postal, or both :latitude and :longitude/)
    end

    it "rejects a latitude without a longitude" do
      expect { build_posting(location: {latitude: 37.7}) }
        .to raise_error(Craigslist::API::ValidationError)
    end
  end

  describe "reply privacy" do
    {none: "A", anonymous: "C", public: "P"}.each do |symbol, code|
      it "maps :#{symbol} to #{code}" do
        expect(build_posting(reply_privacy: symbol).reply_privacy).to eq(code)
      end
    end

    it "accepts a raw code" do
      expect(build_posting(reply_privacy: "P").reply_privacy).to eq("P")
    end

    it "defaults to the anonymous relay address" do
      expect(build_posting.reply_privacy).to eq("C")
    end

    it "rejects anything else" do
      expect { build_posting(reply_privacy: :maybe) }
        .to raise_error(Craigslist::API::ValidationError, /reply_privacy/)
    end
  end

  describe "images" do
    let(:image) { Craigslist::API::Image.from_data("jpegbytes") }

    it "assigns sequential positions when none are given" do
      posting = build_posting(images: [image, image, image])

      expect(posting.images.map(&:position)).to eq([0, 1, 2])
    end

    it "preserves explicitly assigned positions" do
      pinned = Craigslist::API::Image.from_data("bytes", position: 5)
      posting = build_posting(images: [pinned])

      expect(posting.images.first.position).to eq(5)
    end

    it "rejects more than the documented maximum" do
      expect { build_posting(images: Array.new(25) { Craigslist::API::Image.from_data("x") }) }
        .to raise_error(Craigslist::API::ValidationError, /at most 24 images/)
    end

    it "rejects an out-of-range position" do
      out_of_range = Craigslist::API::Image.from_data("bytes", position: 99)

      expect { build_posting(images: [out_of_range]) }
        .to raise_error(Craigslist::API::ValidationError, /positions must be 0\.\.23/)
    end

    it "rejects duplicate positions, which would silently drop an image" do
      first = Craigslist::API::Image.from_data("a", position: 2)
      second = Craigslist::API::Image.from_data("b", position: 2)

      expect { build_posting(images: [first, second]) }
        .to raise_error(Craigslist::API::ValidationError, /duplicate image positions/)
    end
  end

  it "drops nil values from attribute groups" do
    posting = build_posting(housing_basics: {bedrooms: 2, laundry: nil})

    expect(posting.housing_basics).to eq({bedrooms: 2})
  end

  it "is frozen once built" do
    expect(build_posting).to be_frozen
  end

  it "keeps credentials out of inspect output" do
    expect(build_posting.inspect).to include("listing-1", "ctd", "sfo")
  end
end
