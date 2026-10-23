# frozen_string_literal: true

RSpec.describe "Parsing boneyards" do
  it "removes an inline boneyard" do
    screenplay = parse("Action /* hidden */ continues.")
    expect(types(screenplay)).to eq([:action])
    expect(screenplay.first.text).to eq("Action  continues.")
  end

  it "removes a whole-line boneyard" do
    screenplay = parse("/* hidden */")
    expect(screenplay.elements).to be_empty
  end

  it "removes a multi-line boneyard and everything in it" do
    source = <<~FOUNTAIN
      Before.

      /*
      INT. DELETED - DAY
      BRICK
      This never happened.
      */

      After.
    FOUNTAIN

    screenplay = parse(source)
    expect(types(screenplay)).to eq(%i[action action])
    expect(texts(screenplay)).to eq(%w[Before. After.])
  end

  it "does not merge actions across a multi-line boneyard" do
    screenplay = parse("Before.\n/*\nHidden.\n*/\nAfter.")
    expect(types(screenplay)).to eq(%i[action action])
  end

  it "records the removed boneyard text" do
    screenplay = parse("A /* one */ B\n\n/* two\nthree */")
    expect(screenplay.boneyards).to eq([" one ", " two\nthree "])
  end

  it "comments out the rest of the document when unclosed" do
    source = "Action.\n/* never closed\nINT. DELETED - DAY"
    screenplay = parse(source)
    expect(types(screenplay)).to eq([:action])
    expect(screenplay.boneyards.first).to include("never closed")
    expect(screenplay.boneyards.first).to include("INT. DELETED - DAY")
  end

  it "does not break classification of the following line" do
    source = <<~FOUNTAIN
      CUT TO:
      /*
      INT. DELETED - DAY
      BRICK
      Deleted dialogue.
      */
      EXT. PALATIAL MANSION - DAY
    FOUNTAIN

    screenplay = parse(source)
    expect(types(screenplay)).to eq(%i[transition scene_heading])
    expect(screenplay.last.text).to eq("EXT. PALATIAL MANSION - DAY")
  end

  it "handles several boneyards" do
    screenplay = parse("A /* one */ B /* two */ C")
    expect(screenplay.first.text).to eq("A  B  C")
    expect(screenplay.boneyards).to eq([" one ", " two "])
  end

  it "exposes no boneyards when there are none" do
    expect(parse("Action.").boneyards).to eq([])
  end
end
