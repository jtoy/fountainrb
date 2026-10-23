# frozen_string_literal: true

RSpec.describe "Feature integration" do
  subject(:screenplay) { parse(fixture("features.fountain")) }

  it "parses the title page" do
    expect(screenplay.title_page.title).to eq(["Fountain Features"])
    expect(screenplay.title_page.authors).to eq(["Test Author"])
  end

  it "parses sections and synopses" do
    expect(screenplay.sections.map(&:text)).to eq(["Act One"])
    expect(screenplay.sections.first.level).to eq(1)
    expect(screenplay.synopses.map(&:text)).to eq(["Establish the world."])
  end

  it "parses scene headings and scene numbers" do
    expect(screenplay.scenes.map(&:text)).to eq([
      "INT. LAB - NIGHT",
      "MONTAGE",
      "EXT. STREET - DAY"
    ])
    expect(screenplay.scenes.first.scene_number).to eq("1A")
    expect(screenplay.scenes[1].forced?).to be(true)
  end

  it "collects inline notes" do
    expect(screenplay.notes).to include("Check the spelling.")
  end

  it "removes boneyards and records them" do
    expect(screenplay.boneyards.size).to eq(1)
    expect(screenplay.boneyards.first).to include("This scene was cut.")
    expect(texts(screenplay).join("\n")).not_to include("This scene was cut.")
    expect(screenplay.scenes.map(&:text)).not_to include("INT. DELETED - DAY")
  end

  it "parses page breaks and centered text" do
    expect(screenplay.page_breaks.size).to eq(1)
    expect(screenplay.centered.map(&:text)).to eq(["THE END"])
  end

  it "parses forced and automatic transitions" do
    expect(screenplay.transitions.map(&:text)).to eq(["FADE TO BLACK.", "CUT TO:"])
    expect(screenplay.transitions.map(&:forced?)).to eq([true, false])
  end

  it "parses characters, parentheticals and dialogue" do
    expect(screenplay.character_names).to eq(%w[STEEL BRICK])
    expect(screenplay.parentheticals.map(&:text)).to eq(["(via radio)"])
    expect(screenplay.dialogue_blocks.first.text).to eq("Do you read me?")
  end

  it "parses lyrics" do
    expect(screenplay.lyrics.map(&:text)).to eq(["La la la"])
  end

  it "renders without the boneyard" do
    expect(screenplay.to_html).not_to include("This scene was cut.")
    expect(screenplay.to_html).to include('<h2 class="scene-heading" data-scene-number="1A">INT. LAB - NIGHT</h2>')
  end
end
