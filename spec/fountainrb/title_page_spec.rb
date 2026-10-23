# frozen_string_literal: true

RSpec.describe FountainRB::TitlePage do
  def lines(source)
    source.split("\n", -1)
  end

  def parse_page(source)
    result = described_class.parse(lines(source))
    result&.first
  end

  describe ".parse" do
    subject(:page) do
      parse_page(<<~FOUNTAIN)
        Title:
            _**BRICK & STEEL**_
            _**FULL RETIRED**_
        Credit: Written by
        Author: Stu Maschwitz
        Source: Story by KTM
        Draft date: 1/20/2012
        Contact:
            Next Level Productions
            1588 Mission Dr.
            Solvang, CA 93463
      FOUNTAIN
    end

    it "returns a title page" do
      expect(page).to be_a(described_class)
    end

    it "keeps keys in document order" do
      expect(page.keys).to eq(%w[title credit author source draft\ date contact])
    end

    it "collects multi-line title values" do
      expect(page.title).to eq(["_**BRICK & STEEL**_", "_**FULL RETIRED**_"])
    end

    it "reads inline values" do
      expect(page.credit).to eq(["Written by"])
      expect(page.source).to eq(["Story by KTM"])
    end

    it "reads authors" do
      expect(page.authors).to eq(["Stu Maschwitz"])
    end

    it "reads the draft date" do
      expect(page.draft_date).to eq(["1/20/2012"])
    end

    it "collects multi-line contact values" do
      expect(page.contact).to eq([
        "Next Level Productions",
        "1588 Mission Dr.",
        "Solvang, CA 93463"
      ])
    end

    it "returns the first value with #fetch" do
      expect(page.fetch("title")).to eq("_**BRICK & STEEL**_")
      expect(page.fetch("missing")).to be_nil
    end

    it "exposes values through #[] with a case-insensitive key" do
      expect(page["TITLE"]).to eq(page.title)
      expect(page["Draft Date"]).to eq(["1/20/2012"])
    end

    it "reports whether a key exists" do
      expect(page.key?("title")).to be(true)
      expect(page.key?("nope")).to be(false)
    end

    it "enumerates entries" do
      expect(page.map { |key, _values| key }.first).to eq("title")
    end

    it "exposes a plain hash" do
      expect(page.to_h["author"]).to eq(["Stu Maschwitz"])
    end

    it "is not empty" do
      expect(page).not_to be_empty
    end

    it "compares by value" do
      expect(parse_page("Title: X")).to eq(parse_page("Title: X"))
      expect(parse_page("Title: X")).not_to eq(parse_page("Title: Y"))
    end

    it "has a readable inspect" do
      expect(page.inspect).to start_with("#<FountainRB::TitlePage")
    end
  end

  describe ".parse edge cases" do
    it "accepts a tab-indented continuation" do
      page = parse_page("Title:\n\tTabbed title")
      expect(page.title).to eq(["Tabbed title"])
    end

    it "accepts a three-space indented continuation" do
      page = parse_page("Title:\n   Three spaces")
      expect(page.title).to eq(["Three spaces"])
    end

    it "does not accept a two-space indented continuation" do
      result = described_class.parse(lines("Title:\n  Two spaces"))
      expect(result).not_to be_nil
      expect(result.first.title).to eq([])
      expect(result.last).to eq(1)
    end

    it "appends repeated keys" do
      page = parse_page("Author: A\nAuthor: B")
      expect(page["author"]).to eq(%w[A B])
    end

    it "normalises case and whitespace in keys" do
      page = parse_page("TITLE: X\nDraft   date: Y")
      expect(page.keys).to eq(["title", "draft date"])
    end

    it "retains unknown keys" do
      page = parse_page("Title: X\nCustom key: value")
      expect(page["custom key"]).to eq(["value"])
    end

    it "ignores a key with no value and no continuation" do
      page = parse_page("Contact:")
      expect(page["contact"]).to eq([])
    end

    it "returns nil when there is no title page" do
      expect(described_class.parse(lines("INT. HOUSE - DAY"))).to be_nil
    end

    it "stops at the first blank line" do
      result = described_class.parse(lines("Title: X\n\nINT. HOUSE - DAY"))
      expect(result.first.title).to eq(["X"])
      expect(result.last).to eq(1)
    end

    it "stops at a line that is neither a key nor an indented value" do
      result = described_class.parse(lines("Title: X\nNot a key"))
      expect(result.first.title).to eq(["X"])
      expect(result.last).to eq(1)
    end
  end

  describe ".detect?" do
    it "detects a known key" do
      expect(described_class.detect?(lines("Title: X"))).to be(true)
    end

    it "detects a title page that starts with an unknown key followed by a key" do
      expect(described_class.detect?(lines("Custom: X\nAuthor: Y"))).to be(true)
    end

    it "does not mistake a transition for a title page" do
      expect(described_class.detect?(lines("CUT TO:\n\nEXT. HOUSE - DAY"))).to be(false)
    end

    it "does not mistake a scene heading for a title page" do
      expect(described_class.detect?(lines("INT. HOUSE - DAY\n\nAction."))).to be(false)
    end

    it "does not mistake action for a title page" do
      expect(described_class.detect?(lines("He walks in.\n\nAction."))).to be(false)
    end

    it "accepts a single draft-date title page" do
      expect(described_class.detect?(lines("Draft date: 6/23/2012"))).to be(true)
    end
  end

  describe "integration with the parser" do
    it "attaches the title page to the screenplay" do
      screenplay = parse("Title: My Script\nAuthor: Someone\n\nINT. HOUSE - DAY")
      expect(screenplay.title_page.title).to eq(["My Script"])
      expect(screenplay.title_page.authors).to eq(["Someone"])
    end

    it "keeps source line numbers for the body" do
      screenplay = parse("Title: My Script\nAuthor: Someone\n\nINT. HOUSE - DAY")
      expect(screenplay.first.line).to eq(4)
    end

    it "handles a screenplay that is only a title page" do
      screenplay = parse("Title: My Script")
      expect(screenplay.title_page.title).to eq(["My Script"])
      expect(screenplay.elements).to be_empty
    end

    it "ignores leading blank lines before the title page" do
      screenplay = parse("\n\nTitle: My Script\n\nAction.")
      expect(screenplay.title_page.title).to eq(["My Script"])
      expect(screenplay.first).to be_a(FountainRB::Action)
    end

    it "exposes combined author and authors keys" do
      screenplay = parse("Author: First\nAuthors: Second\n\nAction.")
      expect(screenplay.title_page.authors).to eq(%w[First Second])
    end

    it "exposes copyright and notes keys" do
      screenplay = parse("Title: X\nCopyright: 2025\nNotes: A note\n\nAction.")
      expect(screenplay.title_page.copyright).to eq(["2025"])
      expect(screenplay.title_page.notes).to eq(["A note"])
    end
  end
end
