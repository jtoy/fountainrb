# frozen_string_literal: true

module FountainRB
  # Turns raw Fountain source into a flat stream of typed tokens.
  #
  # The tokenizer is deliberately context sensitive: Fountain's rules depend
  # on blank lines (a character cue must be preceded by one, a transition must
  # be uppercase and end in "TO:", and so on). Each token therefore records
  # the type it would be interpreted as in context.
  class Tokenizer
    # A single classified source line.
    Token = Struct.new(:type, :text, :line, :meta, keyword_init: true) do
      def [](key)
        meta && meta[key]
      end

      def forced?
        !!self[:forced]
      end
    end

    # Lines beginning with one of these (followed by a dot or space) are scene
    # headings. Longer alternatives come first so combined prefixes win over
    # the bare "INT"/"EXT" alternatives. In addition to the prefixes listed by
    # the Fountain spec, EXT/INT and EXT./INT are accepted because they are
    # common in real screenplays.
    SCENE_PREFIX = %r{\A(?:(?:INT|EXT)\.?/(?:INT|EXT)|INT|EXT|EST|I/E)[.\s]}i

    PAGE_BREAK = /\A={3,}\z/
    SECTION = /\A(#+)[ \t]*(.*)\z/
    SYNOPSIS = /\A=(.*)\z/
    SCENE_NUMBER = /[ \t]*#([A-Za-z0-9._-]+)#[ \t]*\z/
    CHARACTER_EXTENSION = /[ \t]*\(([^()]*)\)[ \t]*\z/
    HARD_BREAK = /\A[ \t]{2,}\z/

    # @return [Array<String>] the contents of every boneyard in the source
    attr_reader :boneyards

    def initialize(source, line_offset: 0)
      @boneyards = []
      @line_offset = line_offset.to_i
      @source = remove_boneyards(normalise(source))
    end

    # @return [Array<String>] the source after boneyards have been removed
    attr_reader :source

    def lines
      @lines ||= source.split("\n", -1)
    end

    # @return [Array<Token>]
    def tokens
      @tokens ||= tokenize
    end

    private

    def normalise(source)
      source.to_s.sub(/\A\uFEFF/, "").gsub(/\r\n?/, "\n")
    end

    # Remove boneyard comments.
    #
    # A boneyard spanning several lines is replaced by the same number of
    # newlines. That keeps line numbers stable and -- because blank lines act
    # as separators in Fountain -- makes the comment behave as if it were
    # never there. An unterminated boneyard comments out the rest of the file.
    def remove_boneyards(source)
      cleaned = source.gsub(%r{/\*.*?\*/}m) do |match|
        @boneyards << match[2...-2]
        "\n" * match.count("\n")
      end

      if (open = cleaned.index("/*"))
        @boneyards << cleaned[(open + 2)..].to_s
        cleaned = cleaned[0...open]
      end

      cleaned
    end

    def token(type, line:, text: "", **meta)
      Token.new(type: type, text: text, line: line, meta: meta)
    end

    def tokenize
      result = []
      prev_blank = true
      dialogue_open = false
      note_open = false
      index = 0

      while index < lines.size
        text = lines[index]
        stripped = text.strip
        lineno = index + 1 + @line_offset

        # A line of two or more spaces is how a writer asks for a blank line
        # inside dialogue. Outside dialogue it is simply a blank line. This
        # check must come before the empty-line check, because a whitespace
        # only line is also "empty" after stripping.
        if text.match?(HARD_BREAK)
          if dialogue_open || note_open
            result << token(:hard_break, line: lineno)
          else
            result << token(:blank, line: lineno)
            prev_blank = true
          end
          index += 1
          next
        end

        if stripped.empty?
          result << token(:blank, line: lineno)
          prev_blank = true
          dialogue_open = false
          note_open = false
          index += 1
          next
        end

        if PAGE_BREAK.match?(stripped)
          result << token(:page_break, line: lineno, text: stripped)
          prev_blank = true
          dialogue_open = false
          note_open = false
          index += 1
          next
        end

        # Sections and synopses are invisible in formatted output, so they do
        # not disturb the blank-line / dialogue context around them.
        if (match = SECTION.match(stripped))
          result << token(:section, line: lineno, text: match[2].strip, level: match[1].length)
          note_open = false
          index += 1
          next
        end

        if (match = SYNOPSIS.match(stripped))
          result << token(:synopsis, line: lineno, text: match[1].strip)
          note_open = false
          index += 1
          next
        end

        if stripped.start_with?("[[")
          note, next_index = note_token_at(index, stripped)
          if note
            result << note
            note_open = false
            index = next_index
            next
          end
        end

        # --- forced elements -------------------------------------------------

        if stripped.match?(/\A\.[A-Za-z0-9]/)
          body, scene_number = scene_parts(stripped[1..])
          result << token(:scene_heading, line: lineno, text: body,
            scene_number: scene_number, forced: true)
          prev_blank = false
          dialogue_open = false
          note_open = false
          index += 1
          next
        end

        if stripped.start_with?("@") && stripped.length > 1
          parts = character_parts(stripped[1..])
          result << token(:character, line: lineno, **parts, forced: true)
          prev_blank = false
          dialogue_open = true
          note_open = false
          index += 1
          next
        end

        if stripped.start_with?("!") && stripped.length > 1
          body = action_text(text.lstrip.sub(/\A!/, ""))
          result << token(:action, line: lineno, text: body, forced: true)
          prev_blank = false
          dialogue_open = false
          note_open = note_depth_after(body, note_open)
          index += 1
          next
        end

        if stripped.start_with?(">")
          body = stripped[1..]
          if body.rstrip.end_with?("<")
            centered = body.rstrip[0...-1].strip
            result << token(:centered, line: lineno, text: centered)
          else
            result << token(:transition, line: lineno, text: body.strip, forced: true)
          end
          prev_blank = false
          dialogue_open = false
          note_open = false
          index += 1
          next
        end

        if stripped.start_with?("~")
          body = stripped[1..].strip
          result << token(:lyrics, line: lineno, text: body)
          prev_blank = false
          dialogue_open = false
          note_open = note_depth_after(body, note_open)
          index += 1
          next
        end

        # --- automatic elements ----------------------------------------------

        unless dialogue_open
          if prev_blank && SCENE_PREFIX.match?(stripped)
            body, scene_number = scene_parts(stripped)
            result << token(:scene_heading, line: lineno, text: body,
              scene_number: scene_number, forced: false)
            prev_blank = false
            note_open = false
            index += 1
            next
          end

          if prev_blank && transition_line?(text)
            result << token(:transition, line: lineno, text: stripped, forced: false)
            prev_blank = false
            note_open = false
            index += 1
            next
          end

          if prev_blank && character_line?(stripped, lines[index + 1])
            parts = character_parts(stripped)
            result << token(:character, line: lineno, **parts, forced: false)
            prev_blank = false
            dialogue_open = true
            note_open = false
            index += 1
            next
          end
        end

        if dialogue_open
          result << if stripped.start_with?("(") && stripped.end_with?(")")
            token(:parenthetical, line: lineno, text: stripped)
          else
            token(:dialogue, line: lineno, text: stripped)
          end
          note_open = note_depth_after(stripped, note_open)
          prev_blank = false
          index += 1
          next
        end

        body = action_text(text)
        result << token(:action, line: lineno, text: body)
        note_open = note_depth_after(body, note_open)
        prev_blank = false
        index += 1
      end

      result
    end

    # A single-line note, or a note spanning consecutive lines. Returns nil
    # when the brackets are not a note (unterminated, followed by extra text,
    # or interrupted by a blank line).
    def note_token_at(index, stripped)
      if (close = stripped.index("]]"))
        trailing = stripped[(close + 2)..].to_s.strip
        return nil unless trailing.empty?

        return [token(:note, line: index + 1, text: stripped[2...close].strip), index + 1]
      end

      collected = [stripped[2..]]
      cursor = index + 1

      while cursor < lines.size
        line = lines[cursor]

        if line.strip.empty?
          if line.match?(HARD_BREAK)
            # A line of two or more spaces keeps the note connected while
            # adding an intentional blank line.
            collected << ""
            cursor += 1
            next
          end

          return nil
        end

        if (close = line.index("]]"))
          return nil unless line[(close + 2)..].to_s.strip.empty?

          collected << line[0...close]
          content = collected.map(&:strip).join("\n").strip
          return [token(:note, line: index + 1, text: content), cursor + 1]
        end

        collected << line
        cursor += 1
      end

      nil
    end

    def scene_parts(text)
      scene_number = nil
      body = text

      if (match = SCENE_NUMBER.match(body))
        scene_number = match[1]
        body = body[0...match.begin(0)]
      end

      [body.rstrip, scene_number]
    end

    def character_parts(text)
      cue = text.rstrip
      dual = false

      if cue.end_with?("^")
        dual = true
        cue = cue[0...-1].rstrip
      end

      extensions = []
      while (match = CHARACTER_EXTENSION.match(cue))
        extensions.unshift(match[1].strip)
        cue = cue[0...match.begin(0)].rstrip
      end

      {name: cue, extensions: extensions, dual: dual}
    end

    def character_line?(stripped, next_line)
      return false if next_line.nil?
      return false if next_line.strip.empty?

      name = character_parts(stripped)[:name]
      return false if name.empty?
      return false unless name.match?(/[A-Za-z]/)

      name == name.upcase
    end

    def transition_line?(text)
      cue = text.lstrip

      # Spaces after the colon deliberately make a transition an Action line.
      cue.end_with?("TO:") && cue.match?(/[A-Za-z]/) && cue == cue.upcase
    end

    # Track whether a multi-line action/dialogue run currently has an
    # unclosed note. Two-space blank lines are allowed inside such a run, so
    # this lets the tokenizer keep the note connected.
    def note_depth_after(text, currently_open)
      open = currently_open
      index = 0

      while index < text.length
        if text[index] == "\\"
          index += 2
        elsif text[index, 2] == "[["
          open = true
          index += 2
        elsif text[index, 2] == "]]"
          open = false
          index += 2
        else
          index += 1
        end
      end

      open
    end

    def action_text(text)
      text.gsub("\t", "    ").rstrip
    end
  end
end
