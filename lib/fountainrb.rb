# frozen_string_literal: true

require_relative "fountainrb/version"
require_relative "fountainrb/errors"
require_relative "fountainrb/inline"
require_relative "fountainrb/elements"
require_relative "fountainrb/title_page"
require_relative "fountainrb/tokenizer"
require_relative "fountainrb/parser"
require_relative "fountainrb/screenplay"
require_relative "fountainrb/validator"
require_relative "fountainrb/html_renderer"
require_relative "fountainrb/plain_text_renderer"

# A pure-Ruby parser for the Fountain screenplay markup language.
#
#   require "fountainrb"
#
#   screenplay = FountainRB.parse(File.read("script.fountain"))
#   screenplay.scenes.first.text      #=> "INT. HOUSE - DAY"
#   screenplay.character_names        #=> ["STEEL", "BRICK"]
#   puts screenplay.to_html
#
# See https://fountain.io/syntax/ for the language reference.
module FountainRB
  class << self
    # Parse Fountain source.
    #
    # @param source [String]
    # @return [Screenplay]
    def parse(source)
      Parser.new(source).parse
    end

    # Read and parse a Fountain file.
    #
    # @param path [String, Pathname]
    # @param encoding [String]
    # @return [Screenplay]
    def parse_file(path, encoding: "UTF-8")
      parse(File.read(path, encoding: encoding))
    end

    # Check Fountain source for likely mistakes.
    #
    # Fountain parsing is intentionally forgiving, so this reports problems
    # that would otherwise be silently recovered from: unclosed notes or
    # boneyards, stray closing brackets, malformed scene numbers, and orphan
    # dual-dialogue carets.
    #
    # @param source [String, nil]
    # @return [Array<Issue>]
    def validate(source)
      Validator.new(source).validate
    end

    # True when {validate} finds no issues in +source+.
    #
    # @param source [String, nil]
    # @return [Boolean]
    def valid?(source)
      validate(source).empty?
    end
  end
end
