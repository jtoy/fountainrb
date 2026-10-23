# frozen_string_literal: true

RSpec.describe "Parsing transitions" do
  it "parses an uppercase line ending in TO:" do
    screenplay = parse("CUT TO:\n\nEXT. BRICK'S POOL - DAY")
    expect(types(screenplay)).to eq(%i[transition scene_heading])
    expect(screenplay.first).to be_a(FountainRB::Transition)
    expect(screenplay.first.text).to eq("CUT TO:")
    expect(screenplay.first.forced?).to be(false)
  end

  it "parses SMASH CUT TO:" do
    expect(parse("Action.\n\nSMASH CUT TO:\n\nAction.").elements[1].text).to eq("SMASH CUT TO:")
  end

  it "requires a blank line before the transition" do
    screenplay = parse("Action.\nCUT TO:\n\nAction.")
    expect(types(screenplay)).to eq(%i[action action])
  end

  it "requires uppercase" do
    expect(types(parse("Cut to:\n\nAction."))).to eq(%i[action action])
  end

  it "requires the line to end in TO:" do
    expect(types(parse("FADE IN:\n\nAction."))).to eq(%i[action action])
  end

  it "treats spaces after the colon as action" do
    screenplay = parse("CUT TO:   \n\nAction.")
    expect(types(screenplay)).to eq(%i[action action])
    expect(screenplay.first.text).to eq("CUT TO:")
  end

  it "ignores leading indentation" do
    expect(parse("    CUT TO:\n\nAction.").first).to be_a(FountainRB::Transition)
  end

  it "parses a transition at the end of the document" do
    expect(types(parse("Action.\n\nCUT TO:"))).to eq(%i[action transition])
  end

  describe "forced transitions" do
    it "starts with a greater-than sign" do
      element = parse("Action.\n\n>Burn to White.\n\nAction.").elements[1]
      expect(element).to be_a(FountainRB::Transition)
      expect(element.text).to eq("Burn to White.")
      expect(element.forced?).to be(true)
    end

    it "allows lowercase" do
      element = parse(">burn to white.").first
      expect(element).to be_a(FountainRB::Transition)
      expect(element.text).to eq("burn to white.")
    end

    it "accepts a completely empty transition" do
      element = parse(">").first
      expect(element).to be_a(FountainRB::Transition)
      expect(element.text).to eq("")
    end
  end

  it "is not a centered element when there is no closing angle bracket" do
    expect(types(parse(">THE END"))).to eq([:transition])
  end

  it "can be forced to action by using two colons with spaces" do
    screenplay = parse("CUT TO:  ")
    expect(types(screenplay)).to eq([:action])
  end

  it "exposes transitions through the screenplay" do
    screenplay = parse("CUT TO:\n\nSMASH CUT TO:")
    expect(screenplay.transitions.map(&:text)).to eq(["CUT TO:", "SMASH CUT TO:"])
  end

  it "serialises the forced flag" do
    expect(parse(">Burn to White.").first.to_h["forced"]).to be(true)
  end
end
