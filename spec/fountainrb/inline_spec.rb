# frozen_string_literal: true

RSpec.describe FountainRB::Inline do
  def parsed(text)
    described_class.parse(text).map(&:to_h)
  end

  describe ".parse" do
    it "returns an empty list for nil" do
      expect(described_class.parse(nil)).to eq([])
    end

    it "returns an empty list for an empty string" do
      expect(described_class.parse("")).to eq([])
    end

    it "returns a single text node for plain text" do
      expect(parsed("hello")).to eq([{"type" => "text", "text" => "hello"}])
    end

    it "parses italics" do
      expect(parsed("*italics*")).to eq([
        {
          "type" => "italic",
          "children" => [{"type" => "text", "text" => "italics"}]
        }
      ])
    end

    it "parses bold" do
      expect(parsed("**bold**")).to eq([
        {
          "type" => "bold",
          "children" => [{"type" => "text", "text" => "bold"}]
        }
      ])
    end

    it "parses bold italics" do
      expect(parsed("***bold italics***")).to eq([
        {
          "type" => "bold_italic",
          "children" => [{"type" => "text", "text" => "bold italics"}]
        }
      ])
    end

    it "parses underline" do
      expect(parsed("_underline_")).to eq([
        {
          "type" => "underline",
          "children" => [{"type" => "text", "text" => "underline"}]
        }
      ])
    end

    it "keeps surrounding text separate" do
      expect(parsed("a *b* c")).to eq([
        {"type" => "text", "text" => "a "},
        {"type" => "italic", "children" => [{"type" => "text", "text" => "b"}]},
        {"type" => "text", "text" => " c"}
      ])
    end

    it "parses nested emphasis" do
      expect(parsed("_an *italicized* word_")).to eq([
        {
          "type" => "underline",
          "children" => [
            {"type" => "text", "text" => "an "},
            {"type" => "italic", "children" => [{"type" => "text", "text" => "italicized"}]},
            {"type" => "text", "text" => " word"}
          ]
        }
      ])
    end

    it "parses bold inside italics" do
      expect(parsed("*a **b** c*")).to eq([
        {
          "type" => "italic",
          "children" => [
            {"type" => "text", "text" => "a "},
            {"type" => "bold", "children" => [{"type" => "text", "text" => "b"}]},
            {"type" => "text", "text" => " c"}
          ]
        }
      ])
    end

    it "parses underlining around italics" do
      html = described_class.to_html(
        "From what seems like only INCHES AWAY. _Steel's face FILLS the *Leupold Mark 4* scope_."
      )
      expect(html).to eq(
        "From what seems like only INCHES AWAY. " \
        "<u>Steel&#39;s face FILLS the <em>Leupold Mark 4</em> scope</u>."
      )
    end

    it "does not emphasise when the opening delimiter is followed by whitespace" do
      expect(described_class.to_html("* not italic*")).to eq("* not italic*")
    end

    it "does not emphasise when the closing delimiter is preceded by whitespace" do
      expect(described_class.to_html("*not italic *")).to eq("*not italic *")
    end

    it "leaves an unmatched asterisk alone" do
      source = "He dialed *69 and then *23, and then hung up."
      expect(described_class.to_html(source)).to eq(source)
    end

    it "emphasises when both delimiters touch non-whitespace" do
      source = "He dialed *69 and then 23*, and then hung up."
      expect(described_class.to_html(source)).to eq(
        "He dialed <em>69 and then 23</em>, and then hung up."
      )
    end

    it "does not carry emphasis across line breaks" do
      source = "As he rattles off the long list, Brick and Steel *share a look.\n\nThis is going to be BAD.*"
      expect(described_class.to_html(source)).to eq(
        "As he rattles off the long list, Brick and Steel *share a look.<br><br>" \
        "This is going to be BAD.*"
      )
    end

    it "supports escaping markup characters" do
      expect(described_class.to_html("**\\*9765\\***")).to eq("<strong>*9765*</strong>")
    end

    it "keeps backslashes that do not escape markup" do
      expect(described_class.to_html("C:\\path")).to eq("C:\\path")
    end

    it "allows an escaped asterisk to prevent emphasis" do
      expect(described_class.to_html("\\*not italic\\*")).to eq("*not italic*")
    end

    it "produces line break nodes" do
      expect(parsed("a\nb")).to eq([
        {"type" => "text", "text" => "a"},
        {"type" => "line_break"},
        {"type" => "text", "text" => "b"}
      ])
    end

    it "parses an inline note" do
      expect(parsed("Action [[note]] more")).to eq([
        {"type" => "text", "text" => "Action "},
        {"type" => "note", "text" => "note"},
        {"type" => "text", "text" => " more"}
      ])
    end

    it "parses several notes on one line" do
      expect(parsed("[[a]] and [[b]]")).to eq([
        {"type" => "note", "text" => "a"},
        {"type" => "text", "text" => " and "},
        {"type" => "note", "text" => "b"}
      ])
    end

    it "parses a note spanning a single line break" do
      nodes = described_class.parse("[[first\nsecond]]")
      expect(nodes.size).to eq(1)
      expect(nodes.first).to be_a(FountainRB::Inline::Note)
      expect(nodes.first.text).to eq("first\nsecond")
    end

    it "can allow a note across a connected blank line" do
      nodes = described_class.parse("[[first\n\nsecond]]", connected_blanks: true)
      expect(nodes.size).to eq(1)
      expect(nodes.first).to be_a(FountainRB::Inline::Note)
      expect(nodes.first.text).to eq("first\n\nsecond")
    end

    it "does not parse a note across a blank line" do
      expect(described_class.parse("[[first\n\nsecond]]")).to all(be_a(FountainRB::Inline::Text).or(be_a(FountainRB::Inline::LineBreak)))
      expect(described_class.to_html("[[first\n\nsecond]]")).to eq("[[first<br><br>second]]")
    end

    it "leaves an unterminated note as literal text" do
      expect(described_class.to_html("foo [[bar")).to eq("foo [[bar")
    end

    it "does not treat an escaped note opener as a note" do
      expect(described_class.to_html("\\[[not a note]]")).to eq("[[not a note]]")
    end

    it "does not parse markup inside a note" do
      nodes = described_class.parse("[[*raw* _markup_]]")
      expect(nodes.size).to eq(1)
      expect(nodes.first.to_h).to eq("type" => "note", "text" => "*raw* _markup_")
    end
  end

  describe ".to_html" do
    it "renders italics" do
      expect(described_class.to_html("*hi*")).to eq("<em>hi</em>")
    end

    it "renders bold" do
      expect(described_class.to_html("**hi**")).to eq("<strong>hi</strong>")
    end

    it "renders bold italics" do
      expect(described_class.to_html("***hi***")).to eq("<strong><em>hi</em></strong>")
    end

    it "renders underline" do
      expect(described_class.to_html("_hi_")).to eq("<u>hi</u>")
    end

    it "omits notes by default" do
      expect(described_class.to_html("a [[note]] b")).to eq("a  b")
    end

    it "renders notes when asked" do
      expect(described_class.to_html("a [[note]] b", notes: true)).to eq(
        'a <span class="note">note</span> b'
      )
    end

    it "renders line breaks as <br>" do
      expect(described_class.to_html("a\nb")).to eq("a<br>b")
    end

    it "can render a note spanning a connected blank line" do
      html = described_class.to_html("a [[one

two]] b", notes: true, connected_blanks: true)
      expect(html).to eq('a <span class="note">one

two</span> b')
    end

    it "escapes HTML special characters" do
      expect(described_class.to_html("a < b & c")).to eq("a &lt; b &amp; c")
    end

    it "escapes quotes" do
      expect(described_class.to_html(%q("quoted" and 'single'))).to eq(
        "&quot;quoted&quot; and &#39;single&#39;"
      )
    end

    it "does not transform typographic punctuation" do
      source = "He waits -- then... \"fine\""
      expect(described_class.to_plain_text(source)).to eq(source)
    end
  end

  describe ".to_plain_text" do
    it "strips emphasis markers" do
      expect(described_class.to_plain_text("_an *italicized* word_")).to eq(
        "an italicized word"
      )
    end

    it "drops notes by default" do
      expect(described_class.to_plain_text("a [[note]] b")).to eq("a  b")
    end

    it "keeps notes when asked" do
      expect(described_class.to_plain_text("a [[note]] b", notes: true)).to eq("a note b")
    end

    it "keeps line breaks" do
      expect(described_class.to_plain_text("a\nb")).to eq("a\nb")
    end
  end

  describe ".escape_html" do
    it "escapes the five HTML metacharacters" do
      expect(described_class.escape_html(%q(<a href="x">'&'</a>))).to eq(
        "&lt;a href=&quot;x&quot;&gt;&#39;&amp;&#39;&lt;/a&gt;"
      )
    end

    it "handles nil" do
      expect(described_class.escape_html(nil)).to eq("")
    end
  end

  describe "node value objects" do
    it "compares text nodes by value" do
      expect(FountainRB::Inline::Text.new("a")).to eq(FountainRB::Inline::Text.new("a"))
      expect(FountainRB::Inline::Text.new("a")).not_to eq(FountainRB::Inline::Text.new("b"))
    end

    it "compares emphasis nodes by style and children" do
      one = FountainRB::Inline::Emphasis.new(:italic, [FountainRB::Inline::Text.new("a")])
      two = FountainRB::Inline::Emphasis.new(:italic, [FountainRB::Inline::Text.new("a")])
      expect(one).to eq(two)
      expect(one.hash).to eq(two.hash)
    end

    it "rejects unknown emphasis styles" do
      expect { FountainRB::Inline::Emphasis.new(:wavy, []) }.to raise_error(ArgumentError)
    end

    it "serialises a line break" do
      expect(FountainRB::Inline::LineBreak.new.to_h).to eq("type" => "line_break")
    end

    it "compares note nodes by value" do
      expect(FountainRB::Inline::Note.new("a")).to eq(FountainRB::Inline::Note.new("a"))
      expect(FountainRB::Inline::Note.new("a").hash).to eq(FountainRB::Inline::Note.new("a").hash)
    end

    it "raises when the base node has no serialisation" do
      expect { FountainRB::Inline::Node.new.to_h }.to raise_error(NotImplementedError)
    end

    it "compares base nodes by their (empty) state" do
      expect(FountainRB::Inline::Node.new).to eq(FountainRB::Inline::Node.new)
    end

    it "hashes text nodes by value" do
      expect(FountainRB::Inline::Text.new("a").hash).to eq(FountainRB::Inline::Text.new("a").hash)
    end

    it "ignores unknown node types when rendering HTML" do
      expect(described_class.render([FountainRB::Inline::Node.new])).to eq("")
    end
  end
end
