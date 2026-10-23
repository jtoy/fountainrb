# frozen_string_literal: true

module FountainRB
  # Base class for every screenplay element.
  #
  # Every element knows:
  #
  # * +text+          -- the element's content with markup removed from the
  #                      element prefix (a leading ".", "!", "@", ">", "~",
  #                      "#" or "=") but with inline emphasis left intact.
  # * +line+          -- the 1-based line number in the source where the
  #                      element begins.
  # * +blank_before+  -- the number of blank source lines immediately before
  #                      the element.
  # * +forced?+       -- whether the writer used an explicit prefix to force
  #                      the element type.
  class Element
    attr_reader :text, :line, :blank_before

    def initialize(text: "", line: nil, blank_before: 0, forced: false)
      @text = text.to_s
      @line = line
      @blank_before = blank_before
      @forced = forced
    end

    # Symbol identifying the element type. Subclasses override.
    def type
      :element
    end

    def forced?
      @forced
    end

    # True for elements that may contain several source lines (and therefore
    # may be merged or extended by the parser).
    def multiline?
      false
    end

    # Append a line of text. Used for line breaks inside multi-line elements.
    def append_line(line)
      @text = "#{@text}\n#{line}"
      self
    end

    # Merge another element of the same type into this one.
    def merge!(other)
      append_line(other.text)
      @forced ||= other.forced?
      self
    end

    # Inline notes contained in this element's text.
    #
    # @return [Array<String>]
    def notes
      Inline.parse(text, connected_blanks: true)
        .select { |node| node.is_a?(Inline::Note) }
        .map(&:text)
    end

    # @return [Hash] a JSON-friendly representation
    def to_h
      hash = {"type" => type.to_s, "text" => text}
      hash["line"] = line if line
      hash["blank_before"] = blank_before if blank_before.to_i.positive?
      hash["forced"] = true if forced?
      hash
    end

    def ==(other)
      other.class == self.class && other.to_h == to_h
    end
    alias_method :eql?, :==

    def hash
      to_h.hash
    end

    def inspect
      attributes = to_h.slice(*(to_h.keys - ["type"]))
      "#<#{self.class.name.split("::").last} #{attributes.inspect}>"
    end
  end

  # A scene heading, e.g. "INT. BRICK'S PATIO - DAY" or ".OPENING TITLES".
  class SceneHeading < Element
    attr_reader :scene_number

    def initialize(scene_number: nil, **kwargs)
      super(**kwargs)
      @scene_number = scene_number
    end

    def type
      :scene_heading
    end

    def to_h
      hash = super
      hash["scene_number"] = scene_number if scene_number
      hash
    end
  end

  # Scene description. May contain several lines and intentional whitespace.
  class Action < Element
    def type
      :action
    end

    def multiline?
      true
    end

    # The action broken into its individual lines.
    def lines
      text.split("\n", -1)
    end
  end

  # A character cue, e.g. "STEEL", "MOM (O. S.)" or "@McCLANE".
  class Character < Element
    attr_reader :name, :extensions

    def initialize(name:, extensions: [], dual: false, **kwargs)
      @name = name.to_s
      @extensions = Array(extensions).map(&:to_s)
      @dual = dual
      super(text: build_text, **kwargs)
    end

    def type
      :character
    end

    # True when the cue ends with a caret, meaning this block is simultaneous
    # with the preceding dialogue block (dual dialogue).
    def dual?
      @dual
    end

    def extension
      extensions.join(" ")
    end

    def to_h
      hash = super
      hash["name"] = name
      hash["extensions"] = extensions unless extensions.empty?
      hash["dual"] = true if dual?
      hash
    end

    private

    def build_text
      [name, *extensions.map { |extension| "(#{extension})" }].join(" ")
    end
  end

  # A line of dialogue.
  class Dialogue < Element
    def type
      :dialogue
    end

    def multiline?
      true
    end

    def lines
      text.split("\n", -1)
    end
  end

  # A parenthetical direction, e.g. "(starting the engine)".
  class Parenthetical < Element
    def type
      :parenthetical
    end

    # The text without the surrounding parentheses.
    def content
      if text.start_with?("(") && text.end_with?(")") && text.length >= 2
        text[1...-1]
      else
        text
      end
    end

    def to_h
      hash = super
      hash["content"] = content
      hash
    end
  end

  # A lyric line, introduced by "~".
  class Lyrics < Element
    def type
      :lyrics
    end

    def multiline?
      true
    end
  end

  # A transition, e.g. "CUT TO:" or ">Burn to White.".
  class Transition < Element
    def type
      :transition
    end
  end

  # Centered text, e.g. "> THE END <". Fountain treats this as a special
  # form of Action.
  class Centered < Element
    def type
      :centered
    end
  end

  # A page break: a line of three or more equals signs.
  class PageBreak < Element
    def type
      :page_break
    end
  end

  # An outline section, e.g. "# Act One" or "## Sequence".
  class Section < Element
    attr_reader :level

    def initialize(level:, **kwargs)
      super(**kwargs)
      @level = level
    end

    def type
      :section
    end

    def to_h
      hash = super
      hash["level"] = level
      hash
    end
  end

  # A single-line synopsis, e.g. "= Set up the characters.".
  class Synopsis < Element
    def type
      :synopsis
    end
  end

  # A note on its own line.
  class Note < Element
    def type
      :note
    end

    def notes
      [text]
    end
  end
end
