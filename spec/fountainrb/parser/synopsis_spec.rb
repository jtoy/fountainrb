# frozen_string_literal: true

RSpec.describe "Parsing synopses" do
  it "parses an equals-prefixed line" do
    screenplay = parse("= This scene sets up the characters.")
    expect(types(screenplay)).to eq([:synopsis])
    element = screenplay.first
    expect(element).to be_a(FountainRB::Synopsis)
    expect(element.text).to eq("This scene sets up the characters.")
  end

  it "strips the equals sign and spaces" do
    expect(parse("=   Padded   ").first.text).to eq("Padded")
  end

  it "parses a bare equals sign" do
    expect(parse("=").first.text).to eq("")
  end

  it "does not disturb a following scene heading" do
    screenplay = parse("# ACT I\n\n= Set up.\n\nEXT. PATIO - DAY")
    expect(types(screenplay)).to eq(%i[section synopsis scene_heading])
  end

  it "can follow a section without a blank line" do
    screenplay = parse("# ACT I\n= Set up.\nEXT. PATIO - DAY")
    expect(types(screenplay)).to eq(%i[section synopsis scene_heading])
  end

  it "exposes synopses through the screenplay" do
    screenplay = parse("= One\n\n= Two")
    expect(screenplay.synopses.map(&:text)).to eq(%w[One Two])
  end

  it "serialises as synopsis" do
    expect(parse("= One").first.to_h["type"]).to eq("synopsis")
  end
end
