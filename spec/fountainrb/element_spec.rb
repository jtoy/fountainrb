# frozen_string_literal: true

RSpec.describe FountainRB::Element do
  it "has a generic element type" do
    expect(described_class.new.type).to eq(:element)
  end

  it "is single-line by default" do
    expect(described_class.new.multiline?).to be(false)
  end

  it "is not forced by default" do
    expect(described_class.new.forced?).to be(false)
  end

  it "compares by value" do
    expect(described_class.new(text: "a")).to eq(described_class.new(text: "a"))
    expect(described_class.new(text: "a")).not_to eq(described_class.new(text: "b"))
  end

  it "has a value-based hash" do
    expect(described_class.new(text: "a").hash).to eq(described_class.new(text: "a").hash)
  end

  it "does not equal a different element class with the same text" do
    expect(described_class.new(text: "a")).not_to eq(FountainRB::Action.new(text: "a"))
  end

  it "appends a line" do
    element = described_class.new(text: "one")
    expect(element.append_line("two")).to be(element)
    expect(element.text).to eq("one\ntwo")
  end

  it "merges another element of the same type" do
    first = FountainRB::Action.new(text: "one")
    second = FountainRB::Action.new(text: "two", forced: true)
    first.merge!(second)
    expect(first.text).to eq("one\ntwo")
    expect(first.forced?).to be(true)
  end

  it "serialises blank_before when positive" do
    expect(described_class.new(text: "a", blank_before: 2).to_h["blank_before"]).to eq(2)
  end

  it "omits blank_before when zero" do
    expect(described_class.new(text: "a").to_h).not_to have_key("blank_before")
  end

  it "omits the line when unknown" do
    expect(described_class.new(text: "a").to_h).not_to have_key("line")
  end

  it "includes a line number when known" do
    expect(described_class.new(text: "a", line: 7).to_h["line"]).to eq(7)
  end

  it "reports inline notes" do
    expect(described_class.new(text: "a [[note]] b").notes).to eq(["note"])
  end
end

RSpec.describe FountainRB::Action do
  it "is multiline" do
    expect(FountainRB::Action.new.multiline?).to be(true)
  end

  it "splits its lines" do
    expect(FountainRB::Action.new(text: "one\ntwo").lines).to eq(%w[one two])
  end
end

RSpec.describe FountainRB::Dialogue do
  it "is multiline" do
    expect(FountainRB::Dialogue.new.multiline?).to be(true)
  end

  it "splits its lines" do
    expect(FountainRB::Dialogue.new(text: "one\ntwo").lines).to eq(%w[one two])
  end
end

RSpec.describe FountainRB::Lyrics do
  it "is multiline" do
    expect(FountainRB::Lyrics.new.multiline?).to be(true)
  end
end

RSpec.describe FountainRB::Parenthetical do
  it "strips surrounding parentheses in #content" do
    expect(FountainRB::Parenthetical.new(text: "(aside)").content).to eq("aside")
  end

  it "returns the text when there are no surrounding parentheses" do
    expect(FountainRB::Parenthetical.new(text: "aside").content).to eq("aside")
  end

  it "does not treat a single parenthesis as a pair" do
    expect(FountainRB::Parenthetical.new(text: "(").content).to eq("(")
  end
end

RSpec.describe FountainRB::Character do
  it "builds the cue text from the name and extensions" do
    character = FountainRB::Character.new(name: "HANS", extensions: ["V.O.", "CONT'D"])
    expect(character.text).to eq("HANS (V.O.) (CONT'D)")
  end

  it "joins extensions in #extension" do
    character = FountainRB::Character.new(name: "HANS", extensions: ["V.O.", "CONT'D"])
    expect(character.extension).to eq("V.O. CONT'D")
  end

  it "is not dual by default" do
    expect(FountainRB::Character.new(name: "STEEL").dual?).to be(false)
  end
end

RSpec.describe FountainRB::Section do
  it "records its level" do
    section = FountainRB::Section.new(text: "Act", level: 2)
    expect(section.type).to eq(:section)
    expect(section.level).to eq(2)
  end
end

RSpec.describe FountainRB::SceneHeading do
  it "records a scene number" do
    scene = FountainRB::SceneHeading.new(text: "INT. HOUSE - DAY", scene_number: "1A")
    expect(scene.to_h["scene_number"]).to eq("1A")
  end

  it "omits a missing scene number" do
    scene = FountainRB::SceneHeading.new(text: "INT. HOUSE - DAY")
    expect(scene.to_h).not_to have_key("scene_number")
  end
end

RSpec.describe FountainRB::DualDialogue do
  it "exposes both blocks" do
    left = FountainRB::DialogueBlock.new(FountainRB::Character.new(name: "A"), [])
    right = FountainRB::DialogueBlock.new(FountainRB::Character.new(name: "B"), [])
    dual = described_class.new(left, right)
    expect(dual.blocks).to eq([left, right])
  end

  it "serialises both sides" do
    left = FountainRB::DialogueBlock.new(FountainRB::Character.new(name: "A"), [])
    right = FountainRB::DialogueBlock.new(FountainRB::Character.new(name: "B"), [])
    expect(described_class.new(left, right).to_h["type"]).to eq("dual_dialogue")
  end
end

RSpec.describe FountainRB::DialogueBlock do
  it "collects notes from the cue and its parts" do
    character = FountainRB::Character.new(name: "STEEL [[cue note]]")
    note = FountainRB::Note.new(text: "block note")
    block = described_class.new(character, [note])
    expect(block.notes).to eq(["cue note", "block note"])
  end
end
