# frozen_string_literal: true

module FountainRB
  # The optional title page at the start of a Fountain document.
  #
  # Title page data is written as +key: value+ pairs. Values may be inline or
  # indented on following lines (three or more spaces, or a tab). A single key
  # may have several values (for example a two-line title or a mailing
  # address).
  #
  #   Title:
  #       BRICK & STEEL
  #       FULL RETIRED
  #   Credit: Written by
  #   Author: Stu Maschwitz
  #   Contact:
  #       Next Level Productions
  #       Solvang, CA 93463
  class TitlePage
    include Enumerable

    # Keys the Fountain spec recommends. Unknown keys are still kept.
    KNOWN_KEYS = [
      "title",
      "credit",
      "author",
      "authors",
      "source",
      "draft date",
      "contact",
      "copyright",
      "notes",
      "date",
      "revision"
    ].freeze

    # A key starts with a letter, may contain spaces, and ends with a colon.
    KEY_PATTERN = /\A([A-Za-z][A-Za-z0-9 ._\/'&()\-]*?):[ \t]*(.*)\z/

    # Continuation values are indented by three or more spaces or a tab.
    INDENTED_PATTERN = /\A(?:[ \t]{3,}|\t)/

    # @return [Hash{String => Array<String>}] normalised key => values
    attr_reader :entries

    def initialize
      @entries = {}
    end

    # Detect a title page starting at +start+ in +lines+.
    #
    # A title page is only recognised when the first line looks like a key and
    # either the key is a known title-page key or a second key line follows
    # immediately. This keeps scripts that happen to begin with "CUT TO:"
    # from being mistaken for a title page.
    def self.detect?(lines, start = 0)
      line = lines[start]
      return false unless line

      match = KEY_PATTERN.match(line.lstrip)
      return false unless match

      key = normalise_key(match[1])
      following = lines[start + 1]

      KNOWN_KEYS.include?(key) || (following && KEY_PATTERN.match?(following.lstrip))
    end

    # Parse the title page starting at +start+.
    #
    # @return [Array(TitlePage, Integer), nil] the page and the index of the
    #   first line after it, or nil when no title page is present.
    def self.parse(lines, start = 0)
      return nil unless detect?(lines, start)

      page = new
      key = nil
      index = start

      while index < lines.size
        line = lines[index]
        break if line.strip.empty?

        if key && line.match?(INDENTED_PATTERN)
          page.add(key, line.strip)
        elsif (match = KEY_PATTERN.match(line.lstrip))
          key = normalise_key(match[1])
          value = match[2].to_s.strip
          page.add(key, value) unless value.empty?
        else
          break
        end

        index += 1
      end

      [page, index]
    end

    def self.normalise_key(key)
      key.to_s.strip.downcase.gsub(/\s+/, " ")
    end

    # Add +value+ under +key+.
    def add(key, value)
      key = self.class.normalise_key(key)
      (@entries[key] ||= []) << value.to_s
      self
    end

    # Values for a key (case-insensitive).
    #
    # @return [Array<String>]
    def [](key)
      (@entries[self.class.normalise_key(key)] || []).dup
    end

    # First value for a key, or nil.
    def fetch(key)
      self[key].first
    end

    def key?(key)
      @entries.key?(self.class.normalise_key(key))
    end

    def keys
      @entries.keys
    end

    def each(&block)
      @entries.each(&block)
    end

    def empty?
      @entries.empty?
    end

    # Convenience readers. Each returns an array of values (a title may span
    # several lines).
    def title
      self["title"]
    end

    def credit
      self["credit"]
    end

    # Values for "Author" and "Authors", in that order.
    def authors
      self["author"] + self["authors"]
    end

    def source
      self["source"]
    end

    def draft_date
      self["draft date"] + self["date"]
    end

    def contact
      self["contact"]
    end

    def copyright
      self["copyright"]
    end

    def notes
      self["notes"]
    end

    def to_h
      @entries.each_with_object({}) { |(key, values), hash| hash[key] = values.dup }
    end

    def ==(other)
      other.is_a?(TitlePage) && other.to_h == to_h
    end

    def inspect
      "#<FountainRB::TitlePage #{to_h.inspect}>"
    end
  end
end
