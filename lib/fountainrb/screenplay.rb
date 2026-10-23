# frozen_string_literal: true

module FountainRB
  # A character cue together with the parentheticals, dialogue and notes that
  # belong to it.
  class DialogueBlock
    attr_reader :character, :parts

    def initialize(character, parts = [])
      @character = character
      @parts = parts
    end

    def dual?
      character.dual?
    end

    def dialogue
      parts.select { |part| part.is_a?(Dialogue) }
    end

    def parentheticals
      parts.select { |part| part.is_a?(Parenthetical) }
    end

    def notes
      character.notes + parts.flat_map(&:notes)
    end

    # All spoken text in the block, separated by newlines.
    def text
      dialogue.map(&:text).join("\n")
    end

    def to_h
      {
        "type" => "dialogue_block",
        "character" => character.to_h,
        "parts" => parts.map(&:to_h)
      }
    end
  end

  # Two dialogue blocks that are spoken simultaneously.
  class DualDialogue
    attr_reader :left, :right

    def initialize(left, right)
      @left = left
      @right = right
    end

    def blocks
      [left, right]
    end

    def to_h
      {
        "type" => "dual_dialogue",
        "left" => left.to_h,
        "right" => right.to_h
      }
    end
  end

  # The result of parsing a Fountain document.
  #
  # A screenplay enumerates its elements (in source order) and provides
  # convenience accessors plus renderers.
  #
  #   screenplay = FountainRB.parse(File.read("brick_and_steel.fountain"))
  #   screenplay.title_page.title       #=> ["BRICK & STEEL", "FULL RETIRED"]
  #   screenplay.scenes.first.text      #=> "EXT. BRICK'S PATIO - DAY"
  #   screenplay.character_names        #=> ["STEEL", "BRICK", ...]
  #   puts screenplay.to_html
  class Screenplay
    include Enumerable

    attr_reader :source, :title_page, :elements, :boneyards

    def initialize(source: "", title_page: nil, elements: [], boneyards: [])
      @source = source
      @title_page = title_page
      @elements = elements
      @boneyards = boneyards
    end

    def each(&block)
      elements.each(&block)
    end

    def [](index)
      elements[index]
    end

    def size
      elements.size
    end
    alias_method :length, :size

    def empty?
      elements.empty?
    end

    def first
      elements.first
    end

    def last
      elements.last
    end

    # Elements of a given type symbol, e.g. +:dialogue+.
    def of_type(type)
      elements.select { |element| element.type == type }
    end

    def scenes
      elements.select { |element| element.is_a?(SceneHeading) }
    end
    alias_method :scene_headings, :scenes

    def action
      elements.select { |element| element.is_a?(Action) }
    end

    def characters
      elements.select { |element| element.is_a?(Character) }
    end

    def dialogues
      elements.select { |element| element.is_a?(Dialogue) }
    end
    alias_method :dialogue, :dialogues

    def parentheticals
      elements.select { |element| element.is_a?(Parenthetical) }
    end

    def lyrics
      elements.select { |element| element.is_a?(Lyrics) }
    end

    def transitions
      elements.select { |element| element.is_a?(Transition) }
    end

    def centered
      elements.select { |element| element.is_a?(Centered) }
    end

    def page_breaks
      elements.select { |element| element.is_a?(PageBreak) }
    end

    def sections
      elements.select { |element| element.is_a?(Section) }
    end

    def synopses
      elements.select { |element| element.is_a?(Synopsis) }
    end

    # Every note, both standalone and inline.
    #
    # @return [Array<String>]
    def notes
      elements.flat_map(&:notes)
    end

    # Unique character names in order of first appearance.
    def character_names
      characters.map(&:name).uniq
    end

    # Dialogue blocks in source order. Dual-dialogue blocks are returned
    # individually (use {#units} to get the paired form).
    def dialogue_blocks
      units.flat_map do |unit|
        case unit
        when DualDialogue then unit.blocks
        when DialogueBlock then [unit]
        else []
        end
      end
    end

    # Elements grouped for rendering: plain elements, dialogue blocks and
    # dual-dialogue pairs.
    def units
      @units ||= build_units
    end

    # @return [Hash] a JSON-friendly representation of the whole screenplay
    def to_h
      hash = {
        "title_page" => title_page&.to_h,
        "elements" => elements.map(&:to_h)
      }
      hash["boneyards"] = boneyards.dup unless boneyards.empty?
      hash
    end

    def to_json(*args)
      require "json"
      to_h.to_json(*args)
    end

    # Validation issues for the screenplay's source.
    #
    # @see Validator#validate
    # @return [Array<Issue>]
    def issues
      Validator.new(source, screenplay: self).validate
    end

    # True when the screenplay's source has no validation issues.
    #
    # @return [Boolean]
    def valid?
      issues.empty?
    end

    # Render the screenplay as HTML.
    #
    # @see HTMLRenderer#initialize
    def to_html(**options)
      HTMLRenderer.new(**options).render(self)
    end

    # Render the screenplay as plain text.
    #
    # @see PlainTextRenderer#initialize
    def to_plain_text(**options)
      PlainTextRenderer.new(**options).render(self)
    end

    def ==(other)
      other.is_a?(Screenplay) &&
        other.title_page == title_page &&
        other.elements == elements
    end

    def inspect
      "#<FountainRB::Screenplay elements=#{elements.size} title_page=#{!title_page.nil?}>"
    end

    private

    def build_units
      result = []
      index = 0

      while index < elements.size
        element = elements[index]

        unless element.is_a?(Character)
          result << element
          index += 1
          next
        end

        parts = []
        index += 1
        while index < elements.size && dialogue_part?(elements[index])
          parts << elements[index]
          index += 1
        end

        block = DialogueBlock.new(element, parts)
        result << if element.dual? && result.last.is_a?(DialogueBlock)
          DualDialogue.new(result.pop, block)
        else
          block
        end
      end

      result
    end

    def dialogue_part?(element)
      element.is_a?(Parenthetical) || element.is_a?(Dialogue) || element.is_a?(Note)
    end
  end
end
