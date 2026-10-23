# frozen_string_literal: true

RSpec.describe "Parsing scene headings" do
  def heading(source)
    parse(source).first
  end

  it "recognises INT" do
    element = heading("INT. HOUSE - DAY")
    expect(element).to be_a(FountainRB::SceneHeading)
    expect(element.text).to eq("INT. HOUSE - DAY")
  end

  it "recognises EXT" do
    expect(heading("EXT. HOUSE - NIGHT").text).to eq("EXT. HOUSE - NIGHT")
  end

  it "recognises EST" do
    expect(heading("EST. HOUSE - DAY").text).to eq("EST. HOUSE - DAY")
  end

  it "recognises INT./EXT" do
    expect(heading("INT./EXT. CAR - DAY").text).to eq("INT./EXT. CAR - DAY")
  end

  it "recognises INT/EXT" do
    expect(heading("INT/EXT. CAR - DAY").text).to eq("INT/EXT. CAR - DAY")
  end

  it "recognises EXT/INT as a practical extension" do
    expect(heading("EXT/INT. SORORITY HOUSE - THE DOORWAY").text).to eq(
      "EXT/INT. SORORITY HOUSE - THE DOORWAY"
    )
  end

  it "recognises EXT./INT. as a practical extension" do
    expect(heading("EXT./INT. CAR - DAY").text).to eq("EXT./INT. CAR - DAY")
  end

  it "recognises I/E" do
    expect(heading("I/E. CAR - DAY").text).to eq("I/E. CAR - DAY")
  end

  it "recognises a prefix followed by a space" do
    expect(heading("INT HOUSE - DAY").text).to eq("INT HOUSE - DAY")
  end

  it "is case insensitive" do
    element = heading("ext. brick's pool - day")
    expect(element).to be_a(FountainRB::SceneHeading)
    expect(element.text).to eq("ext. brick's pool - day")
  end

  it "does not require uppercase" do
    element = heading("int. the house - night")
    expect(element).to be_a(FountainRB::SceneHeading)
  end

  it "requires a blank line before the heading" do
    screenplay = parse("Action.\nINT. HOUSE - DAY")
    expect(types(screenplay)).to eq([:action])
    expect(screenplay.first.text).to eq("Action.\nINT. HOUSE - DAY")
  end

  it "recognises a heading after a blank line" do
    screenplay = parse("Action.\n\nINT. HOUSE - DAY")
    expect(types(screenplay)).to eq(%i[action scene_heading])
  end

  it "still recognises the basic prefixes after the combined prefix" do
    %w[INT. EXT. EST. I/E.].each do |prefix|
      expect(types(parse("#{prefix} CAR - DAY"))).to eq([:scene_heading])
    end
  end

  it "recognises a heading at the start of the document" do
    expect(types(parse("INT. HOUSE - DAY"))).to eq([:scene_heading])
  end

  it "does not recognise words that merely start with a prefix" do
    screenplay = parse("INTERIOR HOUSE - DAY")
    expect(types(screenplay)).to eq([:action])
  end

  it "is not confused by a heading with no dot" do
    expect(types(parse("INTRO TO RUBY"))).to eq([:action])
  end

  describe "forced scene headings" do
    it "starts with a single period" do
      element = heading(".SNIPER SCOPE POV")
      expect(element).to be_a(FountainRB::SceneHeading)
      expect(element.text).to eq("SNIPER SCOPE POV")
      expect(element.forced?).to be(true)
    end

    it "removes the period" do
      expect(heading(".OPENING TITLES").text).to eq("OPENING TITLES")
    end

    it "may start with a digit" do
      expect(heading(".1 - DOG").text).to eq("1 - DOG")
    end

    it "does not treat an ellipsis as a forced heading" do
      source = "...where the second-rate carnival is parked."
      expect(types(parse(source))).to eq([:action])
    end

    it "does not treat !! forced action as a heading" do
      element = heading("!INT. HOUSE - DAY")
      expect(element).to be_a(FountainRB::Action)
      expect(element.text).to eq("INT. HOUSE - DAY")
      expect(element.forced?).to be(true)
    end
  end

  describe "scene numbers" do
    {
      "INT. HOUSE - DAY #1#" => "1",
      "INT. HOUSE - DAY #1A#" => "1A",
      "INT. HOUSE - DAY #1a#" => "1a",
      "INT. HOUSE - DAY #A1#" => "A1",
      "INT. HOUSE - DAY #I-1-A#" => "I-1-A",
      "INT. HOUSE - DAY #1.#" => "1.",
      "INT. HOUSE - DAY - FLASHBACK (1944) #110A#" => "110A"
    }.each do |source, number|
      it "extracts #{number.inspect} from #{source.inspect}" do
        element = heading(source)
        expect(element.scene_number).to eq(number)
        expect(element.text).not_to include("#")
      end
    end

    it "removes the scene number from the heading text" do
      expect(heading("INT. HOUSE - DAY #1A#").text).to eq("INT. HOUSE - DAY")
    end

    it "allows no space before the number" do
      expect(heading("INT. HOUSE - DAY#1#").scene_number).to eq("1")
    end

    it "leaves hashes that are not at the end alone" do
      element = heading("INT. HOUSE - DAY #NOT-A-NUMBER")
      expect(element.scene_number).to be_nil
      expect(element.text).to eq("INT. HOUSE - DAY #NOT-A-NUMBER")
    end

    it "supports scene numbers on forced headings" do
      element = heading(".MONTAGE #2#")
      expect(element.text).to eq("MONTAGE")
      expect(element.scene_number).to eq("2")
    end
  end

  it "records the source line number" do
    screenplay = parse("Action.\n\nINT. HOUSE - DAY")
    expect(screenplay.last.line).to eq(3)
  end
end
