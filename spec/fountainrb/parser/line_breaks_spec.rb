# frozen_string_literal: true

RSpec.describe "Line break handling" do
  it "treats every carriage return in action as intentional" do
    screenplay = parse("One.\nTwo.\nThree.")
    expect(screenplay.first.text).to eq("One.\nTwo.\nThree.")
  end

  it "treats every carriage return in dialogue as intentional" do
    screenplay = parse("DEALER\nTen.\nFour.\nDealer gets a seven.")
    expect(screenplay.last.text).to eq("Ten.\nFour.\nDealer gets a seven.")
  end

  it "uses a two-space line to keep dialogue connected" do
    screenplay = parse("DEALER\nTen.\nFour.\nDealer gets a seven.\n  \nHit or stand sir?")
    expect(screenplay.last.text).to end_with("seven.\n\nHit or stand sir?")
  end

  it "uses a three-space line to keep dialogue connected" do
    screenplay = parse("DEALER\nTen.\n   \nHit?")
    expect(screenplay.last.text).to eq("Ten.\n\nHit?")
  end

  it "uses a tab-only line to keep dialogue connected" do
    screenplay = parse("DEALER\nTen.\n\t\t\nHit?")
    expect(screenplay.last.text).to eq("Ten.\n\nHit?")
  end

  it "preserves several blank dialogue lines" do
    screenplay = parse("DEALER\nTen.\n  \n  \nHit?")
    expect(screenplay.last.text).to eq("Ten.\n\n\nHit?")
  end

  it "treats a two-space line as a normal blank outside dialogue" do
    screenplay = parse("One.\n  \nTwo.")
    expect(types(screenplay)).to eq(%i[action action])
  end

  it "counts blank lines before elements" do
    screenplay = parse("One.\n\n\n\nTwo.")
    expect(screenplay.elements.map(&:blank_before)).to eq([0, 3])
  end

  it "ends a dialogue block at a real blank line" do
    screenplay = parse("DEALER\nTen.\n\nAction.")
    expect(types(screenplay)).to eq(%i[character dialogue action])
  end

  it "does not add blank lines to single-line elements" do
    screenplay = parse("INT. HOUSE - DAY\n  \n\nAction.")
    expect(screenplay.first.text).to eq("INT. HOUSE - DAY")
  end
end
