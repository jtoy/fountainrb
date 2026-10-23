# frozen_string_literal: true

RSpec.describe "Parsing character cues" do
  it "parses an uppercase cue followed by dialogue" do
    screenplay = parse("STEEL\nHello.")
    expect(types(screenplay)).to eq(%i[character dialogue])
    expect(screenplay.first).to be_a(FountainRB::Character)
    expect(screenplay.first.name).to eq("STEEL")
    expect(screenplay.first.text).to eq("STEEL")
  end

  it "requires a blank line before the cue" do
    screenplay = parse("Action.\nSTEEL\nHello.")
    expect(types(screenplay)).to eq([:action])
    expect(screenplay.first.text).to eq("Action.\nSTEEL\nHello.")
  end

  it "requires a non-blank line after the cue" do
    screenplay = parse("STEEL\n\nHello.")
    expect(types(screenplay)).to eq(%i[action action])
  end

  it "treats a trailing cue with no dialogue as action" do
    screenplay = parse("STEEL")
    expect(types(screenplay)).to eq([:action])
  end

  it "does not accept a lowercase name" do
    screenplay = parse("steel\nHello.")
    expect(types(screenplay)).to eq([:action])
  end

  it "requires at least one letter in the name" do
    screenplay = parse("23\nForty two.")
    expect(types(screenplay)).to eq([:action])
  end

  it "accepts a name with digits and letters" do
    screenplay = parse("R2D2\nBeep.")
    expect(types(screenplay)).to eq(%i[character dialogue])
    expect(screenplay.first.name).to eq("R2D2")
  end

  it "accepts punctuation in the name" do
    screenplay = parse("MR. SMITH\nHello.")
    expect(screenplay.first).to be_a(FountainRB::Character)
    expect(screenplay.first.name).to eq("MR. SMITH")
  end

  it "ignores leading indentation" do
    screenplay = parse("        BRICK\nHi.")
    expect(screenplay.first).to be_a(FountainRB::Character)
    expect(screenplay.first.name).to eq("BRICK")
  end

  it "is case sensitive about the name itself" do
    screenplay = parse("McCLANE\nHello.")
    expect(types(screenplay)).to eq([:action])
  end

  describe "character extensions" do
    it "parses an uppercase extension" do
      screenplay = parse("MOM (O. S.)\nLuke! Come down for supper!")
      character = screenplay.first
      expect(character.name).to eq("MOM")
      expect(character.extensions).to eq(["O. S."])
      expect(character.text).to eq("MOM (O. S.)")
      expect(character.extension).to eq("O. S.")
    end

    it "parses a lowercase extension" do
      screenplay = parse("HANS (on the radio)\nWhat was it you said?")
      character = screenplay.first
      expect(character.name).to eq("HANS")
      expect(character.extensions).to eq(["on the radio"])
      expect(character.text).to eq("HANS (on the radio)")
    end

    it "parses several extensions" do
      screenplay = parse("HANS (V.O.) (CONT'D)\nHello.")
      expect(screenplay.first.name).to eq("HANS")
      expect(screenplay.first.extensions).to eq(["V.O.", "CONT'D"])
      expect(screenplay.first.text).to eq("HANS (V.O.) (CONT'D)")
    end

    it "includes extensions in the JSON representation" do
      hash = parse("HANS (V.O.)\nHello.").first.to_h
      expect(hash["name"]).to eq("HANS")
      expect(hash["extensions"]).to eq(["V.O."])
    end
  end

  describe "forced character cues" do
    it "preserves mixed case with @" do
      screenplay = parse("@McCLANE\nYippie ki-yay!")
      character = screenplay.first
      expect(character).to be_a(FountainRB::Character)
      expect(character.name).to eq("McCLANE")
      expect(character.text).to eq("McCLANE")
      expect(character.forced?).to be(true)
    end

    it "removes the @ from the text" do
      expect(parse("@McCLANE\nHi.").first.text).not_to include("@")
    end

    it "supports extensions on forced cues" do
      character = parse("@McCLANE (V.O.)\nHi.").first
      expect(character.name).to eq("McCLANE")
      expect(character.extensions).to eq(["V.O."])
    end
  end

  it "does not treat a scene heading as a character" do
    screenplay = parse("INT. HOUSE - DAY\n\nAction.")
    expect(screenplay.first).to be_a(FountainRB::SceneHeading)
  end

  it "does not treat a transition as a character" do
    screenplay = parse("CUT TO:\n\nAction.")
    expect(screenplay.first).to be_a(FountainRB::Transition)
  end

  it "exposes the cue through the screenplay" do
    screenplay = parse("STEEL\nHi.\n\nBRICK\nHello.\n\nSTEEL\nAgain.")
    expect(screenplay.characters.map(&:name)).to eq(%w[STEEL BRICK STEEL])
    expect(screenplay.character_names).to eq(%w[STEEL BRICK])
  end
end
