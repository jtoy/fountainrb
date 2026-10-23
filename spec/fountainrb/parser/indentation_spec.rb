# frozen_string_literal: true

RSpec.describe "Indentation handling" do
  it "preserves leading spaces in action" do
    element = parse("    Indented action.").first
    expect(element.text).to eq("    Indented action.")
  end

  it "converts tabs to four spaces in action" do
    element = parse("\tIndented action.").first
    expect(element.text).to eq("    Indented action.")
  end

  it "converts each tab to four spaces" do
    element = parse("\t\tTwo tabs.").first
    expect(element.text).to eq("        Two tabs.")
  end

  it "preserves indentation on continuation action lines" do
    element = parse("First.\n    Second.\n\n    Third.").first
    expect(element.text).to eq("First.\n    Second.")
  end

  it "ignores indentation on scene headings" do
    element = parse("    INT. HOUSE - DAY").first
    expect(element).to be_a(FountainRB::SceneHeading)
    expect(element.text).to eq("INT. HOUSE - DAY")
  end

  it "ignores indentation on character cues" do
    element = parse("        BRICK\nHi.").first
    expect(element).to be_a(FountainRB::Character)
    expect(element.name).to eq("BRICK")
  end

  it "ignores indentation on dialogue" do
    screenplay = parse("STEEL\n        Hello.")
    expect(screenplay.last.text).to eq("Hello.")
  end

  it "ignores indentation on parentheticals" do
    screenplay = parse("STEEL\n    (whispering)\nGo.")
    expect(screenplay[1].text).to eq("(whispering)")
  end

  it "ignores indentation on transitions" do
    element = parse("        CUT TO:\n\nAction.").first
    expect(element).to be_a(FountainRB::Transition)
    expect(element.text).to eq("CUT TO:")
  end

  it "does not convert tabs on transitions" do
    element = parse("\tCUT TO:\n\nAction.").first
    expect(element.text).to eq("CUT TO:")
  end

  it "ignores indentation on lyrics" do
    expect(parse("    ~La la").first.text).to eq("La la")
  end

  it "ignores indentation on centered text" do
    expect(parse("    > THE END <").first.text).to eq("THE END")
  end

  it "ignores indentation on sections" do
    expect(parse("    # Act One").first.text).to eq("Act One")
  end

  it "ignores indentation on synopses" do
    expect(parse("    = A synopsis.").first.text).to eq("A synopsis.")
  end

  it "ignores indentation on forced scene headings" do
    expect(parse("    .MONTAGE").first.text).to eq("MONTAGE")
  end

  it "ignores indentation on forced character cues" do
    element = parse("    @McCLANE\nHi.").first
    expect(element).to be_a(FountainRB::Character)
    expect(element.name).to eq("McCLANE")
  end
end
