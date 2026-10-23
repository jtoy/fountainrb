# frozen_string_literal: true

RSpec.describe "Parsing page breaks" do
  it "parses three equals signs" do
    screenplay = parse("Action.\n\n===\n\nAction.")
    expect(types(screenplay)).to eq(%i[action page_break action])
    expect(screenplay[1]).to be_a(FountainRB::PageBreak)
  end

  it "parses more than three equals signs" do
    expect(types(parse("====="))).to eq([:page_break])
  end

  it "ignores surrounding whitespace" do
    expect(types(parse("   ===   "))).to eq([:page_break])
  end

  it "does not treat two equals signs as a page break" do
    expect(types(parse("=="))).to eq([:synopsis])
  end

  it "does not treat a sentence starting with equals signs as a page break" do
    expect(types(parse("=== not a break"))).to eq([:synopsis])
  end

  it "resets the blank-line context" do
    screenplay = parse("Action.\n===\nINT. HOUSE - DAY")
    expect(types(screenplay)).to eq(%i[action page_break scene_heading])
  end

  it "exposes page breaks through the screenplay" do
    screenplay = parse("===\n\n===")
    expect(screenplay.page_breaks.size).to eq(2)
  end

  it "serialises as page_break" do
    expect(parse("===").first.to_h["type"]).to eq("page_break")
  end
end
