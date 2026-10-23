# frozen_string_literal: true

RSpec.describe "Parsing lyrics" do
  it "parses a tilde-prefixed line" do
    screenplay = parse("~Willy Wonka! Willy Wonka! The amazing chocolatier!")
    expect(types(screenplay)).to eq([:lyrics])
    expect(screenplay.first).to be_a(FountainRB::Lyrics)
    expect(screenplay.first.text).to eq("Willy Wonka! Willy Wonka! The amazing chocolatier!")
  end

  it "removes the tilde" do
    expect(parse("~La la la").first.text).to eq("La la la")
  end

  it "allows a space after the tilde" do
    expect(parse("~ La la la").first.text).to eq("La la la")
  end

  it "merges consecutive lyric lines" do
    screenplay = parse("~Willy Wonka! Willy Wonka!\n~Everybody give a cheer!")
    expect(types(screenplay)).to eq([:lyrics])
    expect(screenplay.first.text).to eq("Willy Wonka! Willy Wonka!\nEverybody give a cheer!")
  end

  it "is always forced" do
    expect(types(parse("Willy Wonka! Willy Wonka!"))).to eq([:action])
  end

  it "preserves lowercase" do
    expect(parse("~quiet singing").first.text).to eq("quiet singing")
  end

  it "ignores leading indentation" do
    expect(parse("    ~La la la").first.text).to eq("La la la")
  end

  it "can follow dialogue" do
    screenplay = parse("STEEL\nHi.\n\n~La la la")
    expect(types(screenplay)).to eq(%i[character dialogue lyrics])
  end

  it "keeps inline markup" do
    expect(parse("~*La* la").first.text).to eq("*La* la")
  end

  it "exposes lyrics through the screenplay" do
    screenplay = parse("~One\n\n~Two")
    expect(screenplay.lyrics.map(&:text)).to eq(%w[One Two])
  end
end
