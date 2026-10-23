# frozen_string_literal: true

RSpec.describe FountainRB::PlainTextRenderer do
  let(:source) do
    <<~FOUNTAIN
      Title: My Script
      Author: A. Writer

      INT. HOUSE - DAY

      An action line.

      STEEL
      (whispering)
      Hello.
    FOUNTAIN
  end

  subject(:text) { parse(source).to_plain_text }

  it "puts scene headings at the left margin" do
    expect(text).to include("\nINT. HOUSE - DAY\n")
  end

  it "includes action text" do
    expect(text).to include("An action line.")
  end

  it "indents character cues" do
    expect(text).to include("\n                    STEEL\n")
  end

  it "indents parentheticals" do
    expect(text).to include("\n                (whispering)\n")
  end

  it "indents dialogue" do
    expect(text).to include("\n        Hello.\n")
  end

  it "ends with a newline" do
    expect(text).to end_with("\n")
  end

  it "includes title page values" do
    expect(text).to include("My Script")
    expect(text).to include("A. Writer")
  end

  it "can omit the title page" do
    expect(parse(source).to_plain_text(title_page: false)).not_to include("A. Writer")
  end

  it "renders transitions at the left margin" do
    screenplay = parse("CUT TO:\n\nAction.")
    expect(screenplay.to_plain_text.lines.first).to eq("CUT TO:\n")
  end

  it "renders lyrics with indentation" do
    expect(parse("~La la").to_plain_text).to eq("        La la\n")
  end

  it "renders centered text with indentation" do
    expect(parse(">THE END<").to_plain_text).to eq("#{" " * 20}THE END\n")
  end

  it "renders dual dialogue side by side" do
    screenplay = parse("STEEL\nHi.\n\nBRICK ^\nHello.")
    expect(screenplay.to_plain_text.lines.any? { |line| line.include?("STEEL") && line.include?("BRICK") }).to be(true)
  end

  it "omits notes by default" do
    expect(parse("A [[note]] B.").to_plain_text).to eq("A  B.\n")
  end

  it "can include notes" do
    expect(parse("A [[note]] B.").to_plain_text(notes: true)).to eq("A note B.\n")
  end

  it "can include a standalone note" do
    screenplay = parse("Action.\n\n[[a note]]\n\nMore.")
    expect(screenplay.to_plain_text(notes: true)).to include("[[a note]]")
  end

  it "renders each line of a multi-line note" do
    screenplay = parse("[[one\ntwo]]")
    expect(screenplay.to_plain_text(notes: true)).to eq("[[one]]\n[[two]]\n")
  end

  it "can include a note inside a dialogue block" do
    screenplay = parse("STEEL\n[[block note]]\nHello.")
    expect(screenplay.to_plain_text(notes: true)).to include("[[block note]]")
  end

  it "omits sections and synopses by default" do
    screenplay = parse("# Act\n\n= Synopsis\n\nAction.")
    expect(screenplay.to_plain_text).not_to include("# Act")
    expect(screenplay.to_plain_text).not_to include("= Synopsis")
  end

  it "can include sections and synopses" do
    screenplay = parse("# Act\n\n= Synopsis\n\nAction.")
    text = screenplay.to_plain_text(sections: true, synopses: true)
    expect(text).to include("# Act")
    expect(text).to include("= Synopsis")
  end

  it "omits page breaks by default" do
    expect(parse("A.\n\n===\n\nB.").to_plain_text).not_to include("\f")
  end

  it "can render page breaks as form feeds" do
    expect(parse("A.\n\n===\n\nB.").to_plain_text(page_breaks: true)).to include("\f")
  end

  it "returns an empty string for an empty screenplay" do
    expect(parse("").to_plain_text).to eq("")
  end

  it "strips inline emphasis markers" do
    expect(parse("An *action* line.").to_plain_text).to eq("An action line.\n")
  end
end
