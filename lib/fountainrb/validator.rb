# frozen_string_literal: true

module FountainRB
  # A problem found while validating Fountain source.
  #
  # Validation is about likely mistakes, not about rejecting input: the
  # parser itself always succeeds and falls back to Action for anything it
  # does not understand (Fountain's own error-handling philosophy).
  class Issue
    SEVERITIES = %i[error warning].freeze

    # @return [Symbol] a short machine-readable code, e.g. :unclosed_note
    attr_reader :code

    # @return [String] a human-readable description
    attr_reader :message

    # @return [Integer] 1-based source line
    attr_reader :line

    # @return [Symbol] :error or :warning
    attr_reader :severity

    def initialize(code:, message:, line:, severity: :error)
      raise ArgumentError, "unknown severity: #{severity.inspect}" unless SEVERITIES.include?(severity)

      @code = code.to_sym
      @message = message.to_s
      @line = line
      @severity = severity.to_sym
    end

    def error?
      severity == :error
    end

    def warning?
      severity == :warning
    end

    # @return [Hash] a JSON-friendly representation
    def to_h
      {
        "code" => code.to_s,
        "message" => message,
        "line" => line,
        "severity" => severity.to_s
      }
    end

    def to_s
      "line #{line}: #{message}"
    end

    def ==(other)
      other.is_a?(Issue) && other.to_h == to_h
    end
    alias_method :eql?, :==

    def hash
      to_h.hash
    end

    def inspect
      "#<FountainRB::Issue #{to_h.inspect}>"
    end
  end

  # Checks Fountain source for likely mistakes.
  #
  #   FountainRB.validate(source) #=> [#<Issue ...>, ...]
  #   FountainRB.valid?(source)   #=> true / false
  #
  # The validator looks for problems that the permissive parser would
  # otherwise silently recover from:
  #
  # * an unclosed boneyard (+/*+) or note (+[[+)
  # * a note that spans a blank line (which prevents it from being a note)
  # * closing brackets or boneyards without a matching opener
  # * a scene number missing its closing +#+
  # * a dual-dialogue caret with no preceding dialogue block
  #
  # Use {Issue#severity} to distinguish errors from warnings, and
  # {Issue#line} to point at the source line.
  class Validator
    BONEYARD_PATTERN = %r{/\*.*?\*/}m
    CONNECTED_BLANK = /\A[ \t]{2,}\z/
    MALFORMED_SCENE_NUMBER = /#[A-Za-z0-9._-]+[ \t]*\z/
    VALID_SCENE_NUMBER = /#[A-Za-z0-9._-]+#[ \t]*\z/

    # @return [String] the normalised source being validated
    attr_reader :source

    # @param source [String, nil]
    # @param screenplay [Screenplay, nil] an already parsed screenplay for
    #   +source+ (avoids parsing twice)
    def initialize(source, screenplay: nil)
      @source = normalise(source)
      @screenplay = screenplay
      @issues = []
      @validated = false
    end

    # @return [Array<Issue>] every issue, ordered by line
    def validate
      return @issues if @validated

      @validated = true
      check_boneyards
      check_notes
      check_scene_numbers
      check_dual_dialogue
      @issues.sort_by! { |issue| [issue.line, issue.code.to_s] }
      @issues
    end

    # True when validation found nothing at all.
    #
    # @return [Boolean]
    def valid?
      validate.empty?
    end

    # @return [Array<Issue>] only the errors
    def errors
      validate.select(&:error?)
    end

    # @return [Array<Issue>] only the warnings
    def warnings
      validate.select(&:warning?)
    end

    private

    def normalise(source)
      source.to_s.sub(/\A\uFEFF/, "").gsub(/\r\n?/, "\n")
    end

    def lines
      @lines ||= source.split("\n", -1)
    end

    def screenplay
      @screenplay ||= Parser.new(source).parse
    end

    def add_issue(code, message, line, severity)
      @issues << Issue.new(code: code, message: message, line: line, severity: severity)
    end

    # Source with closed boneyards removed, keeping line numbers stable.
    def boneyard_stripped_source
      @boneyard_stripped_source ||= source.gsub(BONEYARD_PATTERN) do |match|
        "\n" * match.count("\n")
      end
    end

    # Source with boneyards removed and an unterminated boneyard (which
    # comments out the rest of the file) truncated.
    def scan_source
      @scan_source ||= begin
        cleaned = boneyard_stripped_source
        open = cleaned.index("/*")
        open ? cleaned[0...open] : cleaned
      end
    end

    def scan_lines
      @scan_lines ||= scan_source.split("\n", -1)
    end

    def check_boneyards
      remaining = boneyard_stripped_source

      if (open = remaining.index("/*"))
        add_issue(
          :unclosed_boneyard,
          "Boneyard opened with /* is never closed",
          line_at(remaining, open),
          :error
        )
      end

      if (close = remaining.index("*/"))
        add_issue(
          :unexpected_boneyard_close,
          "Boneyard closing */ has no matching /*",
          line_at(remaining, close),
          :warning
        )
      end
    end

    def check_notes
      open_line = nil
      crossed_blank = false

      scan_lines.each_with_index do |line, index|
        lineno = index + 1

        if line.strip.empty?
          crossed_blank = true if open_line && !line.match?(CONNECTED_BLANK)
          next
        end

        position = 0
        while position < line.length
          if line[position] == "\\"
            if line[position + 1, 2] == "[["
              # An escaped opener makes the whole construct literal text, so
              # skip its closing brackets too.
              close = line.index("]]", position + 3)
              position = close ? close + 2 : line.length
            else
              position += 2
            end
          elsif line[position, 2] == "[["
            if open_line.nil?
              open_line = lineno
              crossed_blank = false
            end
            position += 2
          elsif line[position, 2] == "]]"
            if open_line.nil?
              add_issue(
                :unexpected_note_close,
                "Note closing brackets ]] have no matching [[",
                lineno,
                :warning
              )
            else
              if crossed_blank
                add_issue(
                  :note_spans_blank_line,
                  "Note opened on line #{open_line} spans a blank line and will not be parsed as a note",
                  open_line,
                  :warning
                )
              end
              open_line = nil
              crossed_blank = false
            end
            position += 2
          else
            position += 1
          end
        end
      end

      return unless open_line

      add_issue(
        :unclosed_note,
        "Note opened with [[ is never closed",
        open_line,
        :error
      )
    end

    def check_scene_numbers
      screenplay.scenes.each do |scene|
        line = lines[scene.line - 1]
        next if line.nil?
        next if line.match?(VALID_SCENE_NUMBER)
        next unless line.match?(MALFORMED_SCENE_NUMBER)

        add_issue(
          :malformed_scene_number,
          "Scene number is missing its closing #",
          scene.line,
          :warning
        )
      end
    end

    def check_dual_dialogue
      screenplay.units.each do |unit|
        next unless unit.is_a?(DialogueBlock) && unit.dual?

        add_issue(
          :orphan_dual_dialogue,
          "Dual-dialogue caret has no preceding dialogue block",
          unit.character.line,
          :warning
        )
      end
    end

    def line_at(text, index)
      text[0...index].count("\n") + 1
    end
  end
end
