# frozen_string_literal: true

RSpec.describe "Parsing action" do
  it "parses a single line as action" do
    screenplay = parse("He walks into the room.")
    expect(types(screenplay)).to eq([:action])
    expect(screenplay.first.text).to eq("He walks into the room.")
  end

  it "merges consecutive lines into one action element" do
    screenplay = parse("First line.\nSecond line.")
    expect(types(screenplay)).to eq([:action])
    expect(screenplay.first.text).to eq("First line.\nSecond line.")
  end

  it "separates paragraphs at blank lines" do
    screenplay = parse("First paragraph.\n\nSecond paragraph.")
    expect(types(screenplay)).to eq(%i[action action])
    expect(texts(screenplay)).to eq(["First paragraph.", "Second paragraph."])
  end

  it "records how many blank lines precede an element" do
    screenplay = parse("One.\n\n\nTwo.")
    expect(screenplay.elements.map(&:blank_before)).to eq([0, 2])
  end

  it "records leading blank lines" do
    screenplay = parse("\n\nAction.")
    expect(screenplay.first.blank_before).to eq(2)
  end

  it "exposes individual lines" do
    screenplay = parse("One.\nTwo.\nThree.")
    expect(screenplay.first.lines).to eq(%w[One. Two. Three.])
  end

  it "preserves leading spaces" do
    screenplay = parse("He opens the card:\n\n    Scott --\n    Palace Hotel, RM 412\n\nHe hangs up.")
    expect(texts(screenplay)).to eq([
      "He opens the card:",
      "    Scott --\n    Palace Hotel, RM 412",
      "He hangs up."
    ])
  end

  it "converts tabs to four spaces" do
    screenplay = parse("\tTabbed\n\t\tTwice")
    expect(screenplay.first.text).to eq("    Tabbed\n        Twice")
  end

  it "strips trailing whitespace" do
    expect(parse("Action.   ").first.text).to eq("Action.")
  end

  it "does not transform punctuation" do
    source = "He said -- \"hello\" ... it's fine."
    expect(parse(source).first.text).to eq(source)
  end

  it "leaves inline emphasis markup in the element text" do
    screenplay = parse("A *very* nice day.")
    expect(screenplay.first.text).to eq("A *very* nice day.")
    expect(FountainRB::Inline.to_html(screenplay.first.text)).to eq("A <em>very</em> nice day.")
  end

  it "allows forced action with !" do
    element = parse("!UPPERCASE ACTION\nstill action").first
    expect(element).to be_a(FountainRB::Action)
    expect(element.text).to eq("UPPERCASE ACTION\nstill action")
    expect(element.forced?).to be(true)
  end

  it "forces an uppercase line to stay action" do
    screenplay = parse("!SCANNING THE AISLES...\nWhere is that pit boss?")
    expect(types(screenplay)).to eq([:action])
    expect(screenplay.first.text).to eq("SCANNING THE AISLES...\nWhere is that pit boss?")
  end

  it "would otherwise interpret an uppercase line as a character" do
    screenplay = parse("SCANNING THE AISLES...\nWhere is that pit boss?")
    expect(types(screenplay)).to eq(%i[character dialogue])
  end

  it "ignores indentation before the ! of a forced action" do
    element = parse("    !Action.").first
    expect(element).to be_a(FountainRB::Action)
    expect(element.text).to eq("Action.")
  end

  it "exposes a JSON-friendly hash" do
    hash = parse("Action.").first.to_h
    expect(hash).to include("type" => "action", "text" => "Action.", "line" => 1)
  end

  it "is equal to another action with the same attributes" do
    expect(parse("Action.").first).to eq(parse("Action.").first)
    expect(parse("Action.").first).not_to eq(parse("Other.").first)
  end

  it "has a readable inspect" do
    expect(parse("Action.").first.inspect).to start_with("#<Action")
  end
end
