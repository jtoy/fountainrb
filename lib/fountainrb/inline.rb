# frozen_string_literal: true

module FountainRB
  # Parses and renders the inline markup that can appear inside Fountain
  # elements: emphasis, notes and soft line breaks.
  #
  # Fountain follows Markdown's emphasis rules with one twist: underscores
  # mean underline rather than italics.
  #
  #   *italics*            -> :italic
  #   **bold**              -> :bold
  #   ***bold italics***    -> :bold_italic
  #   _underline_           -> :underline
  #   [[a note]]            -> :note
  #
  # Delimiters that are not closed on the same line are left as literal text,
  # and a backslash escapes the following character. Emphasis never spans a
  # line break.
  module Inline
    # A node produced by {Inline.parse}.
    class Node
      def ==(other)
        other.class == self.class && other.state == state
      end
      alias_method :eql?, :==

      def hash
        [self.class, state].hash
      end

      def to_h
        raise NotImplementedError, "#{self.class}#to_h"
      end

      protected

      def state
        []
      end
    end

    # Literal text.
    class Text < Node
      attr_reader :text

      def initialize(text)
        @text = text
      end

      def to_h
        {"type" => "text", "text" => text}
      end

      protected

      def state
        [text]
      end
    end

    # Emphasised text. +style+ is one of +:italic+, +:bold+, +:bold_italic+
    # or +:underline+; +children+ is a list of nodes.
    class Emphasis < Node
      STYLES = %i[italic bold bold_italic underline].freeze

      attr_reader :style, :children

      def initialize(style, children)
        raise ArgumentError, "unknown emphasis style: #{style.inspect}" unless STYLES.include?(style)

        @style = style
        @children = children
      end

      def to_h
        {"type" => style.to_s, "children" => children.map(&:to_h)}
      end

      protected

      def state
        [style, children]
      end
    end

    # A note -- text wrapped in double brackets. Notes are normally omitted
    # from formatted output.
    class Note < Node
      attr_reader :text

      def initialize(text)
        @text = text
      end

      def to_h
        {"type" => "note", "text" => text}
      end

      protected

      def state
        [text]
      end
    end

    # A line break inside an element.
    class LineBreak < Node
      def to_h
        {"type" => "line_break"}
      end
    end

    # Marker => { run length => emphasis style }.
    EMPHASIS_MARKERS = {
      "*" => {3 => :bold_italic, 2 => :bold, 1 => :italic}.freeze,
      "_" => {1 => :underline}.freeze
    }.freeze

    HTML_ESCAPES = {
      "&" => "&amp;",
      "<" => "&lt;",
      ">" => "&gt;",
      '"' => "&quot;",
      "'" => "&#39;"
    }.freeze

    # Characters that a backslash may escape. A backslash before anything
    # else is kept as literal text (as in Markdown).
    ESCAPABLE = "\\*_[]<>#!~^=.\""

    class << self
      # Parse +text+ into a flat list of {Inline} nodes.
      #
      # @param text [String, nil]
      # @param connected_blanks [Boolean] allow a note to span a blank line
      #   (used for element text, where a blank line can only come from a
      #   deliberate two-space dialogue line)
      # @return [Array<Node>]
      def parse(text, connected_blanks: false)
        text = text.to_s
        return [] if text.empty?

        nodes = []
        position = 0

        while position < text.length
          open = find_note_open(text, position)

          if open.nil?
            nodes.concat(parse_emphasis(text[position..]))
            break
          end

          close = find_note_close(text, open + 2, connected_blanks: connected_blanks)

          if close.nil?
            # An unterminated note (or one containing a blank line) is not a
            # note at all; leave it as literal text.
            nodes.concat(parse_emphasis(text[position..]))
            break
          end

          nodes.concat(parse_emphasis(text[position...open])) if open > position
          nodes << Note.new(text[(open + 2)...close])
          position = close + 2
        end

        nodes
      end

      # Convert inline markup to HTML.
      #
      # @param text [String, nil]
      # @param notes [Boolean] render notes as spans (default: false)
      # @param connected_blanks [Boolean] see {#parse}
      # @return [String]
      def to_html(text, notes: false, connected_blanks: false)
        render(parse(text, connected_blanks: connected_blanks), notes: notes)
      end

      # Strip inline markup from +text+.
      #
      # @param text [String, nil]
      # @param notes [Boolean] keep note contents (default: false)
      # @param connected_blanks [Boolean] see {#parse}
      # @return [String]
      def to_plain_text(text, notes: false, connected_blanks: false)
        parse(text, connected_blanks: connected_blanks).map { |node| plain_node(node, notes) }.join
      end

      # Render an already parsed list of nodes.
      def render(nodes, notes: false)
        nodes.map { |node| render_node(node, notes) }.join
      end

      # Escape HTML special characters.
      def escape_html(text)
        text.to_s.gsub(/[&<>"']/, HTML_ESCAPES)
      end

      private

      def parse_emphasis(chunk)
        return [] if chunk.empty?

        nodes = []
        chunk.split("\n", -1).each_with_index do |line, index|
          nodes << LineBreak.new if index.positive?
          nodes.concat(parse_line(line))
        end
        nodes
      end

      def parse_line(line)
        nodes = []
        buffer = +""
        index = 0
        length = line.length

        while index < length
          char = line[index]

          if char == "\\"
            following = line[index + 1]
            if following && ESCAPABLE.include?(following)
              buffer << following
              index += 2
            else
              buffer << char
              index += 1
            end
          elsif char == "*" || char == "_"
            run = char_run(line, index, char)
            style = EMPHASIS_MARKERS[char][run]
            close = style && find_emphasis_close(line, index, char, run)

            if close
              unless buffer.empty?
                nodes << Text.new(buffer)
                buffer = +""
              end
              inner = line[(index + run)...close]
              nodes << Emphasis.new(style, parse_line(inner))
              index = close + run
            else
              buffer << char
              index += 1
            end
          else
            buffer << char
            index += 1
          end
        end

        nodes << Text.new(buffer) unless buffer.empty?
        nodes
      end

      # Length of the run of +char+ starting at +start+.
      def char_run(line, start, char)
        run = 0
        run += 1 while line[start + run] == char
        run
      end

      # Find the index of a closing delimiter of exactly +run+ characters.
      # Escaped characters are skipped and a closing delimiter may not be
      # preceded by whitespace.
      def find_emphasis_close(line, start, char, run)
        content_start = start + run
        return nil if content_start >= line.length
        return nil if line[content_start].match?(/\s/)

        index = content_start

        while index < line.length
          if line[index] == "\\"
            index += 2
          elsif line[index] == char
            length = char_run(line, index, char)
            if length == run && index.positive? && !line[index - 1].match?(/\s/)
              return index
            end
            index += length
          else
            index += 1
          end
        end

        nil
      end

      # Find an unescaped note opener (a "[[" with an even number of
      # preceding backslashes).
      def find_note_open(text, from)
        index = from

        while (open = text.index("[[", index))
          backslashes = 0
          cursor = open - 1
          while cursor >= 0 && text[cursor] == "\\"
            backslashes += 1
            cursor -= 1
          end
          return open if backslashes.even?

          index = open + 1
        end

        nil
      end

      # The end of a note may not cross a blank line unless the caller says
      # the blank line is a deliberate connected break ("Fountain won't look
      # past a double line break").
      def find_note_close(text, from, connected_blanks: false)
        close = text.index("]]", from)
        return nil unless close
        return nil if !connected_blanks && text[from...close].match?(/\n[ \t]*\n/)

        close
      end

      def render_node(node, notes)
        case node
        when Text
          escape_html(node.text)
        when LineBreak
          "<br>"
        when Note
          notes ? %(<span class="note">#{escape_html(node.text)}</span>) : ""
        when Emphasis
          inner = render(node.children, notes: notes)
          case node.style
          when :italic then "<em>#{inner}</em>"
          when :bold then "<strong>#{inner}</strong>"
          when :bold_italic then "<strong><em>#{inner}</em></strong>"
          when :underline then "<u>#{inner}</u>"
          end
        else
          ""
        end
      end

      def plain_node(node, notes)
        case node
        when Text then node.text
        when LineBreak then "\n"
        when Note then notes ? node.text : ""
        when Emphasis then node.children.map { |child| plain_node(child, notes) }.join
        else ""
        end
      end
    end
  end
end
