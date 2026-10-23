# frozen_string_literal: true

RSpec.describe "Parsing dual dialogue" do
  let(:source) do
    <<~FOUNTAIN
      STEEL
      Screw retirement.

      BRICK ^
      Screw retirement.
    FOUNTAIN
  end

  it "marks the second cue as dual" do
    screenplay = parse(source)
    expect(screenplay.characters.map(&:dual?)).to eq([false, true])
  end

  it "removes the caret from the cue text" do
    screenplay = parse(source)
    expect(screenplay.characters.last.text).to eq("BRICK")
    expect(screenplay.characters.last.name).to eq("BRICK")
  end

  it "accepts spaces before the caret" do
    screenplay = parse("STEEL\nHi.\n\nBRICK   ^\nHello.")
    expect(screenplay.characters.last.name).to eq("BRICK")
    expect(screenplay.characters.last.dual?).to be(true)
  end

  it "accepts a caret on a cue with an extension" do
    screenplay = parse("STEEL\nHi.\n\nBRICK (V.O.) ^\nHello.")
    cue = screenplay.characters.last
    expect(cue.name).to eq("BRICK")
    expect(cue.extensions).to eq(["V.O."])
    expect(cue.dual?).to be(true)
    expect(cue.text).to eq("BRICK (V.O.)")
  end

  it "includes the dual flag in JSON" do
    screenplay = parse(source)
    expect(screenplay.characters.last.to_h["dual"]).to be(true)
    expect(screenplay.characters.first.to_h).not_to have_key("dual")
  end

  it "pairs the two blocks in #units" do
    units = parse(source).units
    expect(units.size).to eq(1)
    expect(units.first).to be_a(FountainRB::DualDialogue)
  end

  it "exposes both blocks of a dual pair" do
    dual = parse(source).units.first
    expect(dual.blocks.map { |block| block.character.name }).to eq(%w[STEEL BRICK])
    expect(dual.left.text).to eq("Screw retirement.")
    expect(dual.right.text).to eq("Screw retirement.")
  end

  it "returns individual blocks from #dialogue_blocks" do
    blocks = parse(source).dialogue_blocks
    expect(blocks.size).to eq(2)
    expect(blocks.map { |block| block.character.name }).to eq(%w[STEEL BRICK])
  end

  it "serialises a dual dialogue pair" do
    hash = parse(source).units.first.to_h
    expect(hash["type"]).to eq("dual_dialogue")
    expect(hash["left"]["character"]["name"]).to eq("STEEL")
    expect(hash["right"]["character"]["name"]).to eq("BRICK")
  end

  it "does not pair when there is no preceding dialogue block" do
    screenplay = parse("BRICK ^\nHello.")
    expect(screenplay.units.first).to be_a(FountainRB::DialogueBlock)
    expect(screenplay.units.first.dual?).to be(true)
  end
end
