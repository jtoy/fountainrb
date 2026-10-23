# frozen_string_literal: true

RSpec.describe "Parsing centered text" do
  it "parses text between angle brackets" do
    screenplay = parse(">THE END<")
    expect(types(screenplay)).to eq([:centered])
    expect(screenplay.first).to be_a(FountainRB::Centered)
    expect(screenplay.first.text).to eq("THE END")
  end

  it "ignores spaces between the brackets and the text" do
    expect(parse("> THE END <").first.text).to eq("THE END")
  end

  it "keeps internal spacing" do
    expect(parse(">BRICK  AND  STEEL<").first.text).to eq("BRICK  AND  STEEL")
  end

  it "keeps inline markup" do
    element = parse(">**The End**<").first
    expect(element.text).to eq("**The End**")
    expect(FountainRB::Inline.to_html(element.text)).to eq("<strong>The End</strong>")
  end

  it "parses several centered lines as separate elements" do
    screenplay = parse(">One<\n\n>Two<")
    expect(types(screenplay)).to eq(%i[centered centered])
  end

  it "ignores leading indentation" do
    expect(parse("    > THE END <").first).to be_a(FountainRB::Centered)
  end

  it "is not parsed as a transition" do
    expect(parse("> THE END <").first).not_to be_a(FountainRB::Transition)
  end

  it "exposes centered text through the screenplay" do
    screenplay = parse(">One<\n\n>Two<")
    expect(screenplay.centered.map(&:text)).to eq(%w[One Two])
  end

  it "serialises as centered" do
    expect(parse(">THE END<").first.to_h["type"]).to eq("centered")
  end
end
