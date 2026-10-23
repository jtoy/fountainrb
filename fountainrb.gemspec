# frozen_string_literal: true

require_relative "lib/fountainrb/version"

Gem::Specification.new do |spec|
  spec.name          = "fountainrb"
  spec.version       = FountainRB::VERSION
  spec.authors       = ["Distark"]
  spec.email         = ["dev@distark.com"]

  spec.summary       = "A pure-Ruby parser for Fountain screenplays"
  spec.description   = <<~DESCRIPTION
    fountainrb is a dependency-free Ruby implementation of the Fountain
    screenplay markup language (https://fountain.io/syntax/). It tokenizes
    title pages, scene headings, action, characters, dialogue, parentheticals,
    dual dialogue, lyrics, transitions, centered text, page breaks, sections,
    synopses, notes and boneyards, parses inline emphasis, and can render a
    parsed screenplay to HTML, plain text or JSON.
  DESCRIPTION

  spec.homepage      = "https://github.com/jtoy/fountainrb"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata = {
    "homepage_uri"          => spec.homepage,
    "source_code_uri"       => "#{spec.homepage}/tree/main",
    "changelog_uri"         => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir[
    "lib/**/*.rb",
    "exe/*",
    "README.md",
    "CHANGELOG.md",
    "LICENSE.txt"
  ]
  spec.bindir        = "exe"
  spec.executables   = ["fountainrb"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.12"
end
