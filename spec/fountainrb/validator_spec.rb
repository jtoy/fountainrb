# frozen_string_literal: true

RSpec.describe FountainRB::Validator do
  def issues_for(source)
    described_class.new(source).validate
  end

  def codes_for(source)
    issues_for(source).map(&:code)
  end

  describe "valid documents" do
    it "accepts an empty document" do
      expect(described_class.new("").validate).to eq([])
    end

    it "accepts nil" do
      expect(described_class.new(nil).validate).to eq([])
    end

    it "accepts a normal screenplay" do
      source = <<~FOUNTAIN
        Title: My Script
        Author: A. Writer

        INT. HOUSE - DAY #1#

        An action line.

        STEEL
        (whispering)
        Hello.
      FOUNTAIN

      expect(issues_for(source)).to eq([])
    end

    it "accepts a closed note" do
      expect(issues_for("A [[note]] B.")).to eq([])
    end

    it "accepts a multi-line note" do
      expect(issues_for("A [[one\ntwo]] B.")).to eq([])
    end

    it "accepts a note connected by a two-space blank line" do
      expect(issues_for("[[one\n  \ntwo]]")).to eq([])
    end

    it "accepts a closed boneyard" do
      expect(issues_for("A /* hidden */ B.\n\n/*\nmore\n*/")).to eq([])
    end

    it "ignores notes inside a boneyard" do
      expect(issues_for("/*\n[[never closed\n*/\nAction.")).to eq([])
    end

    it "accepts a valid scene number" do
      expect(issues_for("INT. HOUSE - DAY #1A#")).to eq([])
    end

    it "accepts a paired dual dialogue" do
      expect(issues_for("STEEL\nHi.\n\nBRICK ^\nHello.")).to eq([])
    end

    it "accepts an escaped note opener" do
      expect(issues_for("A \\[[not a note]] B.")).to eq([])
    end

    it "accepts the brick and steel fixture" do
      expect(issues_for(fixture("brick_and_steel.fountain"))).to eq([])
    end

    it "accepts the features fixture" do
      expect(issues_for(fixture("features.fountain"))).to eq([])
    end
  end

  describe "boneyards" do
    it "reports an unclosed boneyard" do
      issues = issues_for("Action.\n/*\nnever closed")
      expect(issues.size).to eq(1)
      expect(issues.first.code).to eq(:unclosed_boneyard)
      expect(issues.first.severity).to eq(:error)
      expect(issues.first.line).to eq(2)
      expect(issues.first.message).to include("never closed")
    end

    it "keeps line numbers accurate after a multi-line boneyard" do
      source = "A.\n/*\nclosed\n*/\nB.\n/*\nnever closed"
      expect(issues_for(source).first.line).to eq(6)
    end

    it "reports a stray boneyard closer" do
      issues = issues_for("Action. */")
      expect(issues.map(&:code)).to eq([:unexpected_boneyard_close])
      expect(issues.first.severity).to eq(:warning)
      expect(issues.first.line).to eq(1)
    end

    it "does not report notes swallowed by an unclosed boneyard" do
      issues = issues_for("/*\n[[never closed")
      expect(issues.map(&:code)).to eq([:unclosed_boneyard])
    end
  end

  describe "notes" do
    it "reports an unclosed note" do
      issues = issues_for("Action.\n[[never closed")
      expect(issues.size).to eq(1)
      expect(issues.first.code).to eq(:unclosed_note)
      expect(issues.first.severity).to eq(:error)
      expect(issues.first.line).to eq(2)
    end

    it "reports a stray note closer" do
      issues = issues_for("Action. ]]")
      expect(issues.map(&:code)).to eq([:unexpected_note_close])
      expect(issues.first.severity).to eq(:warning)
    end

    it "reports a note spanning a true blank line" do
      issues = issues_for("[[first\n\nsecond]]")
      expect(issues.size).to eq(1)
      expect(issues.first.code).to eq(:note_spans_blank_line)
      expect(issues.first.line).to eq(1)
      expect(issues.first.severity).to eq(:warning)
    end

    it "does not report a note connected by spaces" do
      expect(issues_for("[[first\n   \nsecond]]")).to eq([])
    end

    it "does not report a note inside a boneyard" do
      expect(issues_for("/* [[unclosed */\nAction.")).to eq([])
    end

    it "reports multiple stray closers" do
      expect(codes_for("a ]] b ]] c")).to eq(%i[unexpected_note_close unexpected_note_close])
    end
  end

  describe "scene numbers" do
    it "reports a missing closing hash" do
      issues = issues_for("INT. HOUSE - DAY #1")
      expect(issues.size).to eq(1)
      expect(issues.first.code).to eq(:malformed_scene_number)
      expect(issues.first.line).to eq(1)
      expect(issues.first.severity).to eq(:warning)
    end

    it "does not report a properly closed number" do
      expect(issues_for("INT. HOUSE - DAY #12A#")).to eq([])
    end

    it "does not report a heading with no number" do
      expect(issues_for("INT. HOUSE - DAY")).to eq([])
    end

    it "ignores a hash in the middle of a heading" do
      expect(issues_for("INT. HOUSE - DAY #not-a-number here")).to eq([])
    end

    it "reports a malformed number on a forced heading" do
      expect(codes_for(".MONTAGE #2")).to eq([:malformed_scene_number])
    end
  end

  describe "dual dialogue" do
    it "reports an orphan caret" do
      issues = issues_for("STEEL ^\nHello.")
      expect(issues.size).to eq(1)
      expect(issues.first.code).to eq(:orphan_dual_dialogue)
      expect(issues.first.line).to eq(1)
      expect(issues.first.severity).to eq(:warning)
    end

    it "reports a caret after action instead of dialogue" do
      expect(codes_for("Action.\n\nBRICK ^\nHi.")).to eq([:orphan_dual_dialogue])
    end

    it "does not report a properly paired caret" do
      expect(issues_for("STEEL\nHi.\n\nBRICK ^\nHello.")).to eq([])
    end
  end

  describe "issue ordering" do
    it "sorts issues by line" do
      source = "INT. HOUSE - DAY #1\n\n[[never closed"
      issues = issues_for(source)
      expect(issues.map(&:code)).to eq(%i[malformed_scene_number unclosed_note])
      expect(issues.map(&:line)).to eq([1, 3])
    end
  end

  describe "public API" do
    it "exposes valid?" do
      expect(FountainRB.valid?("INT. HOUSE - DAY")).to be(true)
      expect(FountainRB.valid?("[[unclosed")).to be(false)
    end

    it "exposes validate" do
      expect(FountainRB.validate("[[unclosed")).to be_an(Array)
      expect(FountainRB.validate("[[unclosed").first).to be_a(FountainRB::Issue)
    end

    it "exposes errors and warnings" do
      validator = described_class.new("INT. HOUSE - DAY #1\n\n[[unclosed")
      expect(validator.errors.map(&:code)).to eq([:unclosed_note])
      expect(validator.warnings.map(&:code)).to eq([:malformed_scene_number])
      expect(validator.valid?).to be(false)
    end

    it "is memoised" do
      validator = described_class.new("[[unclosed")
      first = validator.validate
      expect(validator.validate).to be(first)
    end

    it "delegates from the screenplay" do
      screenplay = parse("STEEL ^\nHello.")
      expect(screenplay.valid?).to be(false)
      expect(screenplay.issues.map(&:code)).to eq([:orphan_dual_dialogue])
    end

    it "reports a valid screenplay" do
      expect(parse("INT. HOUSE - DAY").valid?).to be(true)
      expect(parse("INT. HOUSE - DAY").issues).to eq([])
    end
  end

  describe FountainRB::Issue do
    subject(:issue) do
      described_class.new(
        code: :unclosed_note,
        message: "Note opened with [[ is never closed",
        line: 3,
        severity: :error
      )
    end

    it "exposes its attributes" do
      expect(issue.code).to eq(:unclosed_note)
      expect(issue.message).to include("never closed")
      expect(issue.line).to eq(3)
      expect(issue.severity).to eq(:error)
    end

    it "knows whether it is an error or a warning" do
      expect(issue.error?).to be(true)
      expect(issue.warning?).to be(false)
    end

    it "serialises to a hash" do
      expect(issue.to_h).to eq(
        "code" => "unclosed_note",
        "message" => "Note opened with [[ is never closed",
        "line" => 3,
        "severity" => "error"
      )
    end

    it "formats as a string" do
      expect(issue.to_s).to eq("line 3: Note opened with [[ is never closed")
    end

    it "compares by value" do
      other = described_class.new(
        code: :unclosed_note,
        message: "Note opened with [[ is never closed",
        line: 3,
        severity: :error
      )
      expect(issue).to eq(other)
      expect(issue.hash).to eq(other.hash)
    end

    it "is not equal to a different issue" do
      other = described_class.new(code: :x, message: "x", line: 1, severity: :warning)
      expect(issue).not_to eq(other)
    end

    it "has a readable inspect" do
      expect(issue.inspect).to start_with("#<FountainRB::Issue")
    end

    it "rejects unknown severities" do
      expect do
        described_class.new(code: :x, message: "x", line: 1, severity: :fatal)
      end.to raise_error(ArgumentError)
    end
  end
end
