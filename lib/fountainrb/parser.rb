# frozen_string_literal: true

module FountainRB
  # Parses Fountain source into a {Screenplay}.
  #
  #   screenplay = FountainRB::Parser.new(source).parse
  #   screenplay.elements.each { |element| puts element.type }
  #
  # Parsing never raises on malformed markup: when in doubt, Fountain returns
  # the text as Action. Unclosed emphasis, notes and boneyards are left as
  # literal text.
  class Parser
    # @return [String] the normalised source being parsed
    attr_reader :source

    def initialize(source)
      @source = normalise(source)
    end

    # @return [Screenplay]
    def parse
      lines = source.split("\n", -1)
      title_page, body_start = split_title_page(lines)

      body = (body_start < lines.size) ? lines[body_start..].join("\n") : ""
      tokenizer = Tokenizer.new(body, line_offset: body_start)

      Screenplay.new(
        source: source,
        title_page: title_page,
        elements: build_elements(tokenizer.tokens),
        boneyards: tokenizer.boneyards
      )
    end

    private

    def normalise(source)
      source.to_s.sub(/\A\uFEFF/, "").gsub(/\r\n?/, "\n")
    end

    def split_title_page(lines)
      start = 0
      start += 1 while start < lines.size && lines[start].strip.empty?
      return [nil, 0] if start >= lines.size

      parsed = TitlePage.parse(lines, start)
      return [nil, 0] unless parsed

      [parsed[0], parsed[1]]
    end

    def build_elements(tokens)
      elements = []
      pending_blanks = 0
      can_merge = false

      tokens.each do |token|
        case token.type
        when :blank
          pending_blanks += 1
          can_merge = false
        when :hard_break
          last = elements.last
          last&.append_line("") if last&.multiline?
        else
          element = build_element(token, pending_blanks)
          pending_blanks = 0

          if can_merge && mergeable?(elements.last, element)
            elements.last.merge!(element)
          else
            elements << element
            can_merge = true
          end
        end
      end

      elements
    end

    def mergeable?(last, element)
      return false if last.nil?

      case element
      when Action then last.is_a?(Action)
      when Dialogue then last.is_a?(Dialogue)
      when Lyrics then last.is_a?(Lyrics)
      else false
      end
    end

    def build_element(token, blank_before)
      base = {line: token.line, blank_before: blank_before}

      case token.type
      when :scene_heading
        SceneHeading.new(
          text: token.text,
          scene_number: token[:scene_number],
          forced: token.forced?,
          **base
        )
      when :action
        Action.new(text: token.text, forced: token.forced?, **base)
      when :character
        Character.new(
          name: token[:name],
          extensions: token[:extensions],
          dual: token[:dual],
          forced: token.forced?,
          **base
        )
      when :parenthetical
        Parenthetical.new(text: token.text, **base)
      when :dialogue
        Dialogue.new(text: token.text, **base)
      when :lyrics
        Lyrics.new(text: token.text, **base)
      when :transition
        Transition.new(text: token.text, forced: token.forced?, **base)
      when :centered
        Centered.new(text: token.text, **base)
      when :page_break
        PageBreak.new(text: token.text, **base)
      when :section
        Section.new(text: token.text, level: token[:level], **base)
      when :synopsis
        Synopsis.new(text: token.text, **base)
      when :note
        Note.new(text: token.text, **base)
      else
        Action.new(text: token.text, **base)
      end
    end
  end
end
