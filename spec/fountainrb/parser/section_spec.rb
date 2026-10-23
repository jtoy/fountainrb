# frozen_string_literal: true

RSpec.describe "Parsing sections" do
  it "parses a level-one section" do
    screenplay = parse("# Act One")
    expect(types(screenplay)).to eq([:section])
    element = screenplay.first
    expect(element).to be_a(FountainRB::Section)
    expect(element.level).to eq(1)
    expect(element.text).to eq("Act One")
  end

  it "nests sections using more hashes" do
    screenplay = parse("# Act\n\n## Sequence\n\n### Scene")
    expect(types(screenplay)).to eq(%i[section section section])
    expect(screenplay.sections.map(&:level)).to eq([1, 2, 3])
    expect(screenplay.sections.map(&:text)).to eq(%w[Act Sequence Scene])
  end

  it "supports deep nesting" do
    expect(parse("###### Deep").first.level).to eq(6)
  end

  it "does not require a space after the hashes" do
    element = parse("#Act").first
    expect(element).to be_a(FountainRB::Section)
    expect(element.text).to eq("Act")
  end

  it "parses a bare hash as an empty section" do
    element = parse("#").first
    expect(element).to be_a(FountainRB::Section)
    expect(element.text).to eq("")
  end

  it "strips trailing whitespace from the title" do
    expect(parse("# Act One   ").first.text).to eq("Act One")
  end

  it "does not disturb a following scene heading" do
    screenplay = parse("Action.\n\n# Act One\nINT. HOUSE - DAY")
    expect(types(screenplay)).to eq(%i[action section scene_heading])
  end

  it "serialises the level" do
    expect(parse("## Sequence").first.to_h).to include("type" => "section", "level" => 2)
  end

  it "exposes sections through the screenplay" do
    screenplay = parse("# One\n\n## Two")
    expect(screenplay.sections.size).to eq(2)
  end
end
