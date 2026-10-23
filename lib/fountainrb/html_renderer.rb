# frozen_string_literal: true

module FountainRB
  # Renders a {Screenplay} as HTML.
  #
  # The output uses semantic class names rather than inline styles so that the
  # caller can supply whatever screenplay stylesheet they like. Sections,
  # synopses and notes are omitted by default because Fountain ignores them in
  # formatted output, but they can be enabled for editing/debug views.
  #
  #   puts screenplay.to_html(notes: true, sections: true)
  class HTMLRenderer
    # @param notes [Boolean] render notes (default: false)
    # @param sections [Boolean] render sections (default: false)
    # @param synopses [Boolean] render synopses (default: false)
    # @param title_page [Boolean] render the title page (default: true)
    # @param page_breaks [Boolean] render page breaks (default: true)
    def initialize(notes: false, sections: false, synopses: false,
      title_page: true, page_breaks: true)
      @notes = notes
      @sections = sections
      @synopses = synopses
      @title_page = title_page
      @page_breaks = page_breaks
    end

    # @param screenplay [Screenplay]
    # @return [String]
    def render(screenplay)
      parts = []

      if @title_page && screenplay.title_page
        parts << render_title_page(screenplay.title_page)
      end

      screenplay.units.each do |unit|
        html = render_unit(unit)
        parts << html unless html.nil? || html.empty?
      end

      %(<div class="fountain">\n#{parts.join("\n")}\n</div>)
    end

    private

    def html(text)
      Inline.to_html(text, notes: @notes, connected_blanks: true)
    end

    def escape(text)
      Inline.escape_html(text)
    end

    def render_unit(unit)
      case unit
      when DialogueBlock then render_dialogue_block(unit)
      when DualDialogue then render_dual_dialogue(unit)
      when SceneHeading then render_scene_heading(unit)
      when Action then render_action(unit)
      when Lyrics then render_lyrics(unit)
      when Transition then render_transition(unit)
      when Centered then render_centered(unit)
      when PageBreak then @page_breaks ? render_page_break : nil
      when Section then @sections ? render_section(unit) : nil
      when Synopsis then @synopses ? render_synopsis(unit) : nil
      when Note then @notes ? render_note(unit) : nil
      end
    end

    def render_title_page(page)
      lines = ['<section class="title-page">']

      page.entries.each do |key, values|
        class_name = key.gsub(/[^a-z0-9]+/, "-")
        lines << %(  <div class="#{class_name}">)
        values.each { |value| lines << %(    <p>#{html(value)}</p>) }
        lines << "  </div>"
      end

      lines << "</section>"
      lines.join("\n")
    end

    def render_scene_heading(element)
      attributes = +%(class="scene-heading")
      if element.scene_number
        attributes << %( data-scene-number="#{escape(element.scene_number)}")
      end
      %(<h2 #{attributes}>#{html(element.text)}</h2>)
    end

    def render_action(element)
      %(<p class="action">#{html(element.text)}</p>)
    end

    def render_lyrics(element)
      %(<p class="lyrics">#{html(element.text)}</p>)
    end

    def render_transition(element)
      %(<p class="transition">#{html(element.text)}</p>)
    end

    def render_centered(element)
      %(<p class="centered">#{html(element.text)}</p>)
    end

    def render_page_break
      %(<div class="page-break"></div>)
    end

    def render_section(element)
      %(<div class="section" data-level="#{element.level}">#{html(element.text)}</div>)
    end

    def render_synopsis(element)
      %(<div class="synopsis">#{html(element.text)}</div>)
    end

    def render_note(element)
      %(<div class="note">#{html(element.text)}</div>)
    end

    def render_dialogue_block(block)
      lines = ['<div class="dialogue-block">']
      lines << %(  <p class="character">#{render_character(block.character)}</p>)

      block.parts.each do |part|
        case part
        when Parenthetical
          lines << %(  <p class="parenthetical">#{html(part.text)}</p>)
        when Dialogue
          lines << %(  <p class="dialogue">#{html(part.text)}</p>)
        when Note
          lines << %(  <p class="note">#{html(part.text)}</p>) if @notes
        end
      end

      lines << "</div>"
      lines.join("\n")
    end

    def render_dual_dialogue(dual)
      lines = ['<div class="dual-dialogue">']
      lines << render_dialogue_block(dual.left)
      lines << render_dialogue_block(dual.right)
      lines << "</div>"
      lines.join("\n")
    end

    def render_character(character)
      parts = [%(<span class="character-name">#{html(character.name)}</span>)]
      character.extensions.each do |extension|
        parts << %( <span class="extension">(#{html(extension)})</span>)
      end
      parts.join
    end
  end
end
