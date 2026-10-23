# frozen_string_literal: true

RSpec.describe "Brick & Steel integration" do
  subject(:screenplay) { parse(fixture("brick_and_steel.fountain")) }

  it "parses the title page" do
    expect(screenplay.title_page.title).to eq(["BRICK & STEEL", "FULL RETIRED"])
    expect(screenplay.title_page.authors).to eq(["Stu Maschwitz"])
    expect(screenplay.title_page.credit).to eq(["Written by"])
    expect(screenplay.title_page.source).to eq(["Story by KTM"])
    expect(screenplay.title_page.draft_date).to eq(["1/20/2012"])
    expect(screenplay.title_page.contact).to eq([
      "Next Level Productions",
      "1588 Mission Dr.",
      "Solvang, CA 93463"
    ])
  end

  it "starts with the patio scene" do
    expect(screenplay.first).to be_a(FountainRB::SceneHeading)
    expect(screenplay.first.text).to eq("EXT. BRICK'S PATIO - DAY")
  end

  it "finds every scene" do
    expect(screenplay.scenes.map(&:text)).to eq([
      "EXT. BRICK'S PATIO - DAY",
      "INT. TRAILER HOME - DAY",
      "EXT. BRICK'S POOL - DAY",
      "SNIPER SCOPE POV",
      "OPENING TITLES",
      "EXT. WOODEN SHACK - DAY",
      "INT. GARAGE - DAY",
      "EXT. PALATIAL MANSION - DAY"
    ])
  end

  it "parses forced scene headings" do
    expect(screenplay.scenes[3].forced?).to be(true)
    expect(screenplay.scenes[4].forced?).to be(true)
  end

  it "finds the characters" do
    expect(screenplay.character_names).to eq([
      "STEEL",
      "BRICK",
      "JACK",
      "DAN",
      "COGNITO",
      "MINION",
      "HANDSOME MAN"
    ])
  end

  it "parses dual dialogue" do
    dual = screenplay.units.grep(FountainRB::DualDialogue).first
    expect(dual).not_to be_nil
    expect(dual.left.character.name).to eq("STEEL")
    expect(dual.right.character.name).to eq("BRICK")
    expect(dual.left.text).to eq("Screw retirement.")
    expect(dual.right.text).to eq("Screw retirement.")
  end

  it "parses transitions" do
    expect(screenplay.transitions.map(&:text)).to eq([
      "SMASH CUT TO:",
      "CUT TO:",
      "CUT TO:",
      "SMASH CUT TO:",
      "CUT TO:",
      "CUT TO:",
      "BURN TO PINK."
    ])
  end

  it "parses parentheticals" do
    expect(screenplay.parentheticals.map(&:text)).to eq([
      "(beer raised)",
      "(in Vietnamese, subtitled)",
      "(pause)",
      "(pause)",
      "(oh crap)",
      "(starting the engine)"
    ])
  end

  it "parses the opening-title centered text" do
    expect(screenplay.centered.map(&:text)).to eq([
      "BRICK BRADDOCK",
      "& DICK STEEL IN",
      "BRICK & STEEL",
      "FULL RETIRED",
      "THE END"
    ])
  end

  it "treats > BURN TO PINK. as a forced transition" do
    transition = screenplay.transitions.find { |element| element.text == "BURN TO PINK." }
    expect(transition).not_to be_nil
    expect(transition.forced?).to be(true)
  end

  it "keeps intentional multi-line action together" do
    action = screenplay.action.find { |element| element.text.start_with?("And then there's a long beat.") }
    expect(action).not_to be_nil
    expect(action.text).to eq(
      "And then there's a long beat.\nLonger than is funny.\nLong enough to be depressing."
    )
  end

  it "keeps emphasis and underline markup in dialogue" do
    dan = screenplay.dialogue_blocks.find { |block| block.character.name == "DAN" }
    expect(dan.text).to eq("Then let's retire them.\n_Permanently_.")
    expect(FountainRB::Inline.to_html(dan.text)).to eq(
      "Then let&#39;s retire them.<br><u>Permanently</u>."
    )
  end

  it "renders to HTML" do
    html = screenplay.to_html
    expect(html).to include('<h2 class="scene-heading">EXT. BRICK&#39;S PATIO - DAY</h2>')
    expect(html).to include('<span class="character-name">STEEL</span>')
    expect(html).to include('<div class="dual-dialogue">')
  end

  it "renders to JSON" do
    require "json"
    json = JSON.parse(screenplay.to_json)
    expect(json["title_page"]["author"]).to eq(["Stu Maschwitz"])
    expect(json["elements"].first["type"]).to eq("scene_heading")
  end

  it "has no notes or boneyards" do
    expect(screenplay.notes).to eq([])
    expect(screenplay.boneyards).to eq([])
  end

  it "is stable across repeated parses" do
    expect(parse(fixture("brick_and_steel.fountain"))).to eq(screenplay)
  end
end
