# frozen_string_literal: true

module FountainRB
  # Base class for every error raised by fountainrb.
  class Error < StandardError; end

  # Raised when source text cannot be read or parsed.
  class ParseError < Error; end
end
