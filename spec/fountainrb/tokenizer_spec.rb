# frozen_string_literal: true

RSpec.describe FountainRB::Tokenizer do
  def tokens(source)
    described_class.new(source).tokens
  end

  def token_types(source)
    tokens(source).map(&:type)
  end

  it "returns no tokens for empty source" do
    expect(tokens("")).to eq([])
  end

  it "classifies the elements of a small scene" do
    source = <<~FOUNTAIN
      INT. HOUSE - DAY

      Action.

      STEEL
      (whispering)
      Hello.
    FOUNTAIN

    expect(token_types(source)).to eq(
      %i[scene_heading blank action blank character parenthetical dialogue blank]
    )
  end

  it "records line numbers" do
    result = tokens("INT. HOUSE - DAY\n\nAction.\n\nSTEEL\nHello.")
    expect(result.reject { |token| token.type == :blank }.map(&:line)).to eq([1, 3, 5, 6])
  end

  it "produces a hard-break token only inside dialogue" do
    expect(token_types("STEEL\nHi.\n  \nBye.")).to eq(
      %i[character dialogue hard_break dialogue]
    )
    expect(token_types("Action.\n  \nMore.")).to eq(%i[action blank action])
  end

  it "keeps an action connected across a two-space line inside a note" do
    expect(token_types("A [[note\n  \nstill note]] B")).to eq(
      %i[action hard_break action]
    )
  end

  it "does not treat an escaped note opener as an open note" do
    expect(token_types("A \\[[not a note]]\n  \nB")).to eq(
      %i[action blank action]
    )
  end

  it "stores character metadata" do
    token = tokens("MOM (O. S.) ^\nHello.").first
    expect(token.type).to eq(:character)
    expect(token[:name]).to eq("MOM")
    expect(token[:extensions]).to eq(["O. S."])
    expect(token[:dual]).to be(true)
    expect(token.forced?).to be(false)
  end

  it "stores forced character metadata" do
    token = tokens("@McCLANE\nHello.").first
    expect(token[:name]).to eq("McCLANE")
    expect(token.forced?).to be(true)
  end

  it "stores scene heading metadata" do
    token = tokens(".MONTAGE #12A#").first
    expect(token.type).to eq(:scene_heading)
    expect(token.text).to eq("MONTAGE")
    expect(token[:scene_number]).to eq("12A")
    expect(token.forced?).to be(true)
  end

  it "stores section levels" do
    token = tokens("### Scene").first
    expect(token[:level]).to eq(3)
  end

  it "normalises CRLF line endings" do
    tokenizer = described_class.new("STEEL\r\nHello.\r\n")
    expect(tokenizer.source).to eq("STEEL\nHello.\n")
  end

  it "strips boneyards and records them" do
    tokenizer = described_class.new("A /* hidden */ B")
    expect(tokenizer.source).to eq("A  B")
    expect(tokenizer.boneyards).to eq([" hidden "])
    expect(tokenizer.tokens.first.type).to eq(:action)
  end

  it "keeps line numbers stable across another boneyard" do
    source = "One.\n/*\nTwo.\n*/\nThree."
    result = described_class.new(source).tokens.reject { |token| token.type == :blank }
    expect(result.map(&:line)).to eq([1, 5])
    expect(result.map(&:text)).to eq(%w[One. Three.])
  end

  it "exposes the token type through #[] as well" do
    token = tokens("STEEL\nHi.").first
    expect(token[:name]).to eq("STEEL")
    expect(token[:missing]).to be_nil
  end
end
