# frozen_string_literal: true

RSpec.describe "Parsing notes" do
  describe "notes on their own line" do
    it "parses a standalone note" do
      screenplay = parse("[[It was supposed to be Vietnamese, right?]]")
      expect(types(screenplay)).to eq([:note])
      element = screenplay.first
      expect(element).to be_a(FountainRB::Note)
      expect(element.text).to eq("It was supposed to be Vietnamese, right?")
    end

    it "removes surrounding blank lines when there are no other elements" do
      screenplay = parse("\n\n[[a note]]\n\n")
      expect(types(screenplay)).to eq([:note])
      expect(screenplay.first.text).to eq("a note")
    end

    it "keeps notes between action elements" do
      screenplay = parse("Before.\n\n[[a note]]\n\nAfter.")
      expect(types(screenplay)).to eq(%i[action note action])
    end

    it "parses a note spanning several lines" do
      screenplay = parse("[[This section needs work.\nEither that, or I need coffee.\nDefinitely coffee.]]")
      expect(types(screenplay)).to eq([:note])
      expect(screenplay.first.text).to eq(
        "This section needs work.\nEither that, or I need coffee.\nDefinitely coffee."
      )
    end

    it "keeps a note connected across a two-space blank line" do
      screenplay = parse("[[first\nsecond\n  \nthird]]")
      expect(types(screenplay)).to eq([:note])
      expect(screenplay.first.text).to eq("first\nsecond\n\nthird")
    end

    it "keeps an inline note connected across a two-space blank line" do
      source = "His hand is an inch from the receiver when the phone RINGS. " \
               "Scott pauses for a moment, suspicious for some reason.[[This section needs work.\n" \
               "Either that, or I need coffee.\n" \
               "  \n" \
               "Definitely coffee.]] He looks around. Phone ringing."

      screenplay = parse(source)
      expect(types(screenplay)).to eq([:action])
      expect(screenplay.first.notes).to eq([
        "This section needs work.\nEither that, or I need coffee.\n\nDefinitely coffee."
      ])
      expect(FountainRB::Inline.to_html(screenplay.first.text, connected_blanks: true)).to eq(
        "His hand is an inch from the receiver when the phone RINGS. " \
        "Scott pauses for a moment, suspicious for some reason. He looks around. Phone ringing."
      )
    end

    it "does not treat a note interrupted by a blank line as one note" do
      screenplay = parse("[[first\n\nsecond]]")
      expect(types(screenplay)).to eq(%i[action action])
      expect(texts(screenplay)).to eq(["[[first", "second]]"])
    end

    it "does not treat an unterminated note as a note" do
      screenplay = parse("[[never closed")
      expect(types(screenplay)).to eq([:action])
    end

    it "is action when text follows the closing brackets" do
      screenplay = parse("[[note]] trailing text")
      expect(types(screenplay)).to eq([:action])
      expect(screenplay.first.notes).to eq(["note"])
    end

    it "is action when text follows the closing brackets of a multi-line note" do
      screenplay = parse("[[first\nsecond]] trailing")
      expect(types(screenplay)).to eq([:action])
      expect(screenplay.first.text).to eq("[[first\nsecond]] trailing")
    end

    it "exposes the note through the screenplay" do
      screenplay = parse("[[one]]\n\n[[two]]")
      expect(screenplay.notes).to eq(%w[one two])
    end

    it "reports itself through Element#notes" do
      expect(parse("[[a note]]").first.notes).to eq(["a note"])
    end
  end

  describe "inline notes" do
    it "collects a note inside action" do
      screenplay = parse(
        "This is the home of THE BOY BAND, AKA DAN and JACK[[Or did we think of actual names?]]."
      )
      expect(types(screenplay)).to eq([:action])
      expect(screenplay.first.notes).to eq(["Or did we think of actual names?"])
      expect(FountainRB::Inline.to_html(screenplay.first.text)).to eq(
        "This is the home of THE BOY BAND, AKA DAN and JACK."
      )
    end

    it "collects several notes from one element" do
      screenplay = parse("A [[one]] B [[two]] C.")
      expect(screenplay.first.notes).to eq(%w[one two])
    end

    it "collects a note inside dialogue" do
      screenplay = parse("STEEL\nHello [[quietly]].\nBye.")
      expect(screenplay.last.notes).to include("quietly")
      expect(parse("STEEL\nHello [[quietly]].\nBye.").notes).to eq(["quietly"])
    end

    it "collects notes from all elements" do
      screenplay = parse("A [[one]].\n\n[[two]]\n\nSTEEL\nHi [[three]].")
      expect(screenplay.notes).to eq(%w[one two three])
    end

    it "leaves an unterminated inline note as literal text" do
      screenplay = parse("A [[not a note")
      expect(screenplay.notes).to eq([])
      expect(screenplay.first.text).to eq("A [[not a note")
    end
  end
end
