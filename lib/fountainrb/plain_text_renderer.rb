# frozen_string_literal: true

module FountainRB
  # Renders a {Screenplay} as plain text with screenplay-ish indentation.
  #
  # This is intentionally simple -- it is useful for quick inspection and for
  # tests, but it is not a typesetter. Lines are not wrapped.
  class PlainTextRenderer
    # Left indentation for each element type.
    INDENTS = {
      character: 20,
      parenthetical: 16,
      dialogue: 8,
      lyrics: 8,
      transition: 0,
      centered: 20
    }.freeze

    # @param notes [Boolean] include notes (default: false)
    # @param sections [Boolean] include sections (default: false)
    # @param synopses [Boolean] include synopses (default: false)
    # @param title_page [Boolean] include the title page (default: true)
    # @param page_breaks [Boolean] include a form feed for page breaks
    def initialize(notes: false, sections: false, synopses: false,
      title_page: true, page_breaks: false)
      @notes = notes
      @sections = sections
      @synopses = synopses
      @title_page = title_page
      @page_breaks = page_breaks
    end

    # @param screenplay [Screenplay]
    # @return [String]
    def render(screenplay)
      lines = []

      if @title_page && screenplay.title_page
        title_lines = render_title_page(screenplay.title_page)
        lines.concat(title_lines) unless title_lines.empty?
      end

      previous = nil
      screenplay.units.each do |unit|
        rendered = render_unit(unit)
        next if rendered.nil?

        lines << "" unless lines.empty? || tight?(previous, unit)
        lines.concat(rendered)
        previous = unit
      end

      result = lines.join("\n").rstrip
      result.empty? ? "" : "#{result}\n"
    end

    private

    def render_unit(unit)
      case unit
      when DialogueBlock then render_dialogue_block(unit)
      when DualDialogue then render_dual_dialogue(unit)
      when SceneHeading then text_lines(unit.text)
      when Action then text_lines(unit.text)
      when Lyrics then indented(unit.text, INDENTS[:lyrics])
      when Transition then [unit.text]
      when Centered then indented(unit.text, INDENTS[:centered])
      when PageBreak then @page_breaks ? ["\f"] : nil
      when Section then @sections ? ["#{"#" * unit.level} #{unit.text}".rstrip] : nil
      when Synopsis then @synopses ? ["= #{unit.text}"] : nil
      when Note then @notes ? note_lines(unit.text) : nil
      end
    end

    def render_title_page(page)
      lines = []

      page.entries.each do |_key, values|
        values.each { |value| lines << Inline.to_plain_text(value, notes: @notes) }
        lines << ""
      end

      lines.pop if lines.last == ""
      lines
    end

    def render_dialogue_block(block)
      character = block.character
      cue = character.name
      character.extensions.each { |extension| cue += " (#{extension})" }

      lines = [indent(cue, INDENTS[:character])]

      block.parts.each do |part|
        case part
        when Parenthetical
          lines << indent(part.text, INDENTS[:parenthetical])
        when Dialogue
          lines.concat(indented(part.text, INDENTS[:dialogue]))
        when Note
          lines.concat(note_lines(part.text)) if @notes
        end
      end

      lines
    end

    def render_dual_dialogue(dual)
      left = render_dialogue_block(dual.left)
      right = render_dialogue_block(dual.right)
      width = [left.map(&:length).max, right.map(&:length).max].max
      left.map { |line| line.ljust(width) }
        .zip(right)
        .map { |l, r| "#{l}  #{r}".rstrip }
    end

    def note_lines(text)
      text.split("\n", -1).map { |line| "[[#{line}]]" }
    end

    def text_lines(text)
      text.split("\n", -1).map { |line| Inline.to_plain_text(line, notes: @notes) }
    end

    def indented(text, count)
      text.split("\n", -1).map { |line| indent(Inline.to_plain_text(line, notes: @notes), count) }
    end

    def indent(line, count)
      line.empty? ? "" : (" " * count) + line
    end

    def tight?(previous, unit)
      previous.is_a?(DialogueBlock) && unit.is_a?(DialogueBlock) && unit.dual?
    end
  end
end
