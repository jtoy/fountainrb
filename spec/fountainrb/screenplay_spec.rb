# frozen_string_literal: true

RSpec.describe FountainRB::Screenplay do
  let(:source) do
    <<~FOUNTAIN
      Title: My Script
      Author: A. Writer

      # Act One

      = Introductions.

      INT. HOUSE - DAY #1#

      An action line.

      STEEL
      (whispering)
      Hello.

      BRICK ^
      Simultaneous.

      CUT TO:

      > THE END <
    FOUNTAIN
  end

  subject(:screenplay) { parse(source) }

  it "is enumerable" do
    expect(screenplay.map(&:type)).to eq(types(screenplay))
  end

  it "reports its size" do
    expect(screenplay.size).to eq(screenplay.elements.size)
    expect(screenplay.length).to eq(screenplay.size)
  end

  it "indexes elements" do
    expect(screenplay[0]).to eq(screenplay.elements[0])
  end

  it "returns the first and last elements" do
    expect(screenplay.first).to eq(screenplay.elements.first)
    expect(screenplay.last).to eq(screenplay.elements.last)
  end

  it "is not empty" do
    expect(screenplay).not_to be_empty
  end

  it "keeps the source" do
    expect(screenplay.source).to include("Title: My Script")
  end

  it "exposes the title page" do
    expect(screenplay.title_page).to be_a(FountainRB::TitlePage)
    expect(screenplay.title_page.title).to eq(["My Script"])
  end

  it "selects elements by type" do
    expect(screenplay.of_type(:scene_heading)).to eq(screenplay.scenes)
  end

  it "exposes scene headings" do
    expect(screenplay.scenes.map(&:text)).to eq(["INT. HOUSE - DAY"])
    expect(screenplay.scene_headings).to eq(screenplay.scenes)
  end

  it "exposes scene numbers" do
    expect(screenplay.scenes.first.scene_number).to eq("1")
  end

  it "exposes action" do
    expect(screenplay.action.map(&:text)).to eq(["An action line."])
  end

  it "exposes characters" do
    expect(screenplay.characters.map(&:name)).to eq(%w[STEEL BRICK])
  end

  it "exposes unique character names in order" do
    screenplay = parse("STEEL\nHi.\n\nBRICK\nHi.\n\nSTEEL\nAgain.")
    expect(screenplay.character_names).to eq(%w[STEEL BRICK])
  end

  it "exposes dialogue" do
    expect(screenplay.dialogues.map(&:text)).to include("Hello.", "Simultaneous.")
    expect(screenplay.dialogue).to eq(screenplay.dialogues)
  end

  it "exposes parentheticals" do
    expect(screenplay.parentheticals.map(&:text)).to eq(["(whispering)"])
  end

  it "exposes transitions" do
    expect(screenplay.transitions.map(&:text)).to eq(["CUT TO:"])
  end

  it "exposes centered text" do
    expect(screenplay.centered.map(&:text)).to eq(["THE END"])
  end

  it "exposes sections and synopses" do
    expect(screenplay.sections.map(&:text)).to eq(["Act One"])
    expect(screenplay.synopses.map(&:text)).to eq(["Introductions."])
  end

  it "exposes lyrics (none here)" do
    expect(screenplay.lyrics).to eq([])
  end

  it "exposes page breaks (none here)" do
    expect(screenplay.page_breaks).to eq([])
  end

  it "exposes notes" do
    expect(parse("[[a note]]").notes).to eq(["a note"])
  end

  it "exposes boneyards" do
    expect(parse("A /* gone */ B").boneyards).to eq([" gone "])
  end

  it "exposes dialogue blocks" do
    blocks = screenplay.dialogue_blocks
    expect(blocks.map { |block| block.character.name }).to eq(%w[STEEL BRICK])
  end

  it "groups units including dual dialogue" do
    expect(screenplay.units.grep(FountainRB::DualDialogue).size).to eq(1)
  end

  describe "#to_h" do
    it "includes the title page and elements" do
      hash = screenplay.to_h
      expect(hash["title_page"]["title"]).to eq(["My Script"])
      expect(hash["elements"]).to be_an(Array)
      expect(hash["elements"].first["type"]).to eq("section")
    end

    it "includes boneyards when present" do
      expect(parse("A /* gone */ B").to_h["boneyards"]).to eq([" gone "])
    end

    it "omits boneyards when there are none" do
      expect(parse("Action.").to_h).not_to have_key("boneyards")
    end

    it "uses nil when there is no title page" do
      expect(parse("Action.").to_h["title_page"]).to be_nil
    end
  end

  describe "#to_json" do
    it "produces valid JSON matching #to_h" do
      require "json"
      expect(JSON.parse(screenplay.to_json)).to eq(screenplay.to_h)
    end
  end

  describe "rendering delegators" do
    it "renders HTML" do
      expect(screenplay.to_html).to include('<div class="fountain">')
    end

    it "renders plain text" do
      expect(screenplay.to_plain_text).to include("INT. HOUSE - DAY")
    end
  end

  it "compares by title page and elements" do
    expect(parse("Action.")).to eq(parse("Action."))
    expect(parse("Action.")).not_to eq(parse("Other."))
    expect(parse("Title: X\n\nAction.")).not_to eq(parse("Action."))
  end

  it "has a readable inspect" do
    expect(screenplay.inspect).to start_with("#<FountainRB::Screenplay")
  end

  it "handles an empty screenplay" do
    screenplay = parse("")
    expect(screenplay).to be_empty
    expect(screenplay.size).to eq(0)
    expect(screenplay.first).to be_nil
    expect(screenplay.title_page).to be_nil
  end
end
