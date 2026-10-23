# frozen_string_literal: true

RSpec.describe "Parsing dialogue" do
  it "parses dialogue after a character cue" do
    screenplay = parse("STEEL\nHello.")
    expect(types(screenplay)).to eq(%i[character dialogue])
    expect(screenplay.last).to be_a(FountainRB::Dialogue)
    expect(screenplay.last.text).to eq("Hello.")
  end

  it "merges consecutive dialogue lines" do
    screenplay = parse("DEALER\nTen.\nFour.\nDealer gets a seven. Hit or stand sir?")
    expect(types(screenplay)).to eq(%i[character dialogue])
    expect(screenplay.last.text).to eq(
      "Ten.\nFour.\nDealer gets a seven. Hit or stand sir?"
    )
  end

  it "exposes individual dialogue lines" do
    screenplay = parse("DEALER\nTen.\nFour.")
    expect(screenplay.last.lines).to eq(%w[Ten. Four.])
  end

  it "ends dialogue at a blank line" do
    screenplay = parse("MONKEY\nDude, I'm a monkey.\n\nAction.")
    expect(types(screenplay)).to eq(%i[character dialogue action])
  end

  it "keeps dialogue open across a line of two spaces" do
    screenplay = parse("DEALER\nTen.\nFour.\nDealer gets a seven.\n  \nHit or stand sir?")
    expect(types(screenplay)).to eq(%i[character dialogue])
    expect(screenplay.last.text).to eq(
      "Ten.\nFour.\nDealer gets a seven.\n\nHit or stand sir?"
    )
  end

  it "does not keep dialogue open across a line of one space" do
    screenplay = parse("DEALER\nTen.\n \nHit or stand sir?")
    expect(types(screenplay)).to eq(%i[character dialogue action])
  end

  it "ignores indentation on dialogue lines" do
    screenplay = parse("STEEL\n    Hello.\n        Indented.")
    expect(screenplay.last.text).to eq("Hello.\nIndented.")
  end

  it "allows uppercase dialogue" do
    screenplay = parse("STEEL\nSCREAMING AT THE TOP OF HIS LUNGS")
    expect(types(screenplay)).to eq(%i[character dialogue])
    expect(screenplay.last.text).to eq("SCREAMING AT THE TOP OF HIS LUNGS")
  end

  it "keeps inline markup in the text" do
    screenplay = parse("DAN\nThen let's retire them.\n_Permanently_.")
    expect(screenplay.last.text).to eq("Then let's retire them.\n_Permanently_.")
    expect(FountainRB::Inline.to_html(screenplay.last.text)).to eq(
      "Then let&#39;s retire them.<br><u>Permanently</u>."
    )
  end

  it "collects inline notes in dialogue" do
    screenplay = parse("STEEL\nHello [[a note]] there.")
    expect(screenplay.last.notes).to eq(["a note"])
  end

  it "parses a block of dialogue with parentheticals" do
    screenplay = parse("STEEL\n(starting the engine)\nSo much for retirement!")
    block = screenplay.dialogue_blocks.first
    expect(block).to be_a(FountainRB::DialogueBlock)
    expect(block.character.name).to eq("STEEL")
    expect(block.parentheticals.map(&:text)).to eq(["(starting the engine)"])
    expect(block.dialogue.map(&:text)).to eq(["So much for retirement!"])
    expect(block.text).to eq("So much for retirement!")
  end

  it "parses dialogue that resumes after a parenthetical" do
    screenplay = parse("STEEL\nHi.\n(pause)\nBye.")
    block = screenplay.dialogue_blocks.first
    expect(block.dialogue.map(&:text)).to eq(%w[Hi. Bye.])
  end

  it "continues dialogue after a section that is on its own line" do
    screenplay = parse("STEEL\nHello.\n# Section\nStill speaking.")
    expect(types(screenplay)).to eq(%i[character dialogue section dialogue])
    expect(screenplay.last).to be_a(FountainRB::Dialogue)
  end
end
