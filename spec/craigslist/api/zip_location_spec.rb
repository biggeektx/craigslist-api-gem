# frozen_string_literal: true

RSpec.describe Craigslist::API::ZipLocation do
  describe ".from" do
    # The shape the live API actually returns, which is not the shape the
    # published OpenAPI spec documents.
    context "with the nested payload" do
      subject(:place) do
        described_class.from(
          "area" => {"abbreviation" => "sfo", "description" => "SF bay area"},
          "subarea" => {"abbreviation" => "sfc", "description" => "city of san francisco"}
        )
      end

      it "reads the area" do
        expect(place.area).to eq("sfo")
        expect(place.area_description).to eq("SF bay area")
      end

      it "reads the subarea" do
        expect(place.subarea).to eq("sfc")
        expect(place.subarea_description).to eq("city of san francisco")
        expect(place).to be_subarea
      end

      it "converts to posting keywords" do
        expect(place.to_h).to eq({area: "sfo", subarea: "sfc"})
      end
    end

    context "when the area has no subarea" do
      subject(:place) do
        described_class.from("area" => {"abbreviation" => "pit", "description" => "pittsburgh, PA"})
      end

      it "reports no subarea" do
        expect(place.subarea).to be_nil
        expect(place).not_to be_subarea
      end

      it "omits subarea from the keywords rather than passing nil" do
        expect(place.to_h).to eq({area: "pit"})
      end
    end

    # Kept because the published spec documents this shape; if craigslist ever
    # matches its own documentation we should not break.
    context "with the flat payload the OpenAPI spec documents" do
      subject(:place) { described_class.from("abbreviation" => "bos", "description" => "boston") }

      it "still reads the area" do
        expect(place.area).to eq("bos")
        expect(place.area_description).to eq("boston")
      end
    end

    it "tolerates an empty payload" do
      expect(described_class.from(nil).area).to be_nil
    end
  end

  it "feeds Posting directly" do
    place = described_class.from(
      "area" => {"abbreviation" => "sfo"}, "subarea" => {"abbreviation" => "sfc"}
    )

    posting = Craigslist::API::Posting.new(
      **place.to_h, key: "k", title: "t", description: "d",
      category: "ctd", location: {postal: "94110"}
    )

    expect(posting.area).to eq("sfo")
    expect(posting.subarea).to eq("sfc")
  end

  it "is frozen" do
    expect(described_class.from(nil)).to be_frozen
  end
end
