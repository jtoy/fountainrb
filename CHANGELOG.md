# Changelog

All notable changes to `fountainrb` are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [1.0.0] - 2025-01-01

### Added

- Pure-Ruby Fountain parser with no runtime dependencies.
- Title page parsing with multi-line values, arbitrary keys and convenience
  readers (`title`, `authors`, `credit`, `source`, `draft_date`, `contact`,
  `copyright`, `notes`).
- Scene headings, including `INT`, `EXT`, `EST`, `INT./EXT`, `INT/EXT`, `I/E`,
  forced headings (`.`), and scene numbers (`#1A#`).
- Action with preserved indentation, tab expansion and blank-line metadata.
- Character cues with extensions, forced cues (`@`) and dual-dialogue carets.
- Dialogue, parentheticals, lyrics (`~`), transitions, centered text, page
  breaks, sections, synopses, notes and boneyards.
- Inline emphasis parser and renderer for italics, bold, bold italics,
  underline, escaping and notes.
- `Screenplay` object model with enumerable elements, scene/character/dialogue
  helpers, dialogue-block grouping and dual-dialogue pairing.
- HTML renderer with semantic classes and configurable sections, synopses,
  notes, title page and page breaks.
- Plain-text renderer.
- JSON serialisation via `Screenplay#to_h` and `Screenplay#to_json`.
- Validation API: `FountainRB.valid?`, `FountainRB.validate`,
  `Screenplay#valid?`, `Screenplay#issues`, with line-numbered
  `FountainRB::Issue` results for unclosed notes/boneyards, stray closers,
  malformed scene numbers and orphan dual-dialogue carets.
- `fountainrb` command line interface with HTML, text, JSON and AST output.
- 500+ RSpec examples, including two full integration fixtures.
