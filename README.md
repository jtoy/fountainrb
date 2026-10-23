# fountainrb

[![CI](https://github.com/jtoy/fountainrb/actions/workflows/ci.yml/badge.svg)](https://github.com/jtoy/fountainrb/actions/workflows/ci.yml)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%202.7-cc342d)](https://www.ruby-lang.org/)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE.txt)

A dependency-free, pure-Ruby parser for [Fountain](https://fountain.io/syntax/)
screenplays.

`fountainrb` turns Fountain source into a structured, enumerable object model
that you can render, inspect, transform, or serialise to JSON. It implements
the complete Fountain syntax — title pages, scene headings, action, characters
and extensions, dialogue, parentheticals, dual dialogue, lyrics, transitions,
centered text, page breaks, sections, synopses, notes, boneyards, and inline
emphasis — and never raises on malformed markup.

```ruby
require "fountainrb"

screenplay = FountainRB.parse(File.read("brick_and_steel.fountain"))

screenplay.title_page.title        #=> ["BRICK & STEEL", "FULL RETIRED"]
screenplay.title_page.authors      #=> ["Stu Maschwitz"]
screenplay.scenes.first.text       #=> "EXT. BRICK'S PATIO - DAY"
screenplay.character_names         #=> ["STEEL", "BRICK", ...]
screenplay.dialogue_blocks.first.text  #=> "Beer's ready!"

puts screenplay.to_html
```

## Installation

Add it to your Gemfile:

```ruby
gem "fountainrb"
```

Until the gem is published on RubyGems, install it straight from GitHub:

```ruby
gem "fountainrb", github: "jtoy/fountainrb"
```

Or install it directly:

```sh
gem install fountainrb
```

There are no runtime dependencies. Ruby 2.7 or newer is required.

## Quick start

```ruby
require "fountainrb"

source = <<~FOUNTAIN
  Title: My First Script
  Author: A. Writer

  INT. KITCHEN - MORNING

  A KETTLE boils. Steam fogs the window.

  MOM (O. S.)
  (calling upstairs)
  Breakfast!

  SAM
  Coming!
FOUNTAIN

screenplay = FountainRB.parse(source)

screenplay.title_page.title       #=> ["My First Script"]
screenplay.scenes.first.text      #=> "INT. KITCHEN - MORNING"
screenplay.characters.map(&:name) #=> ["MOM", "SAM"]

screenplay.elements.each do |element|
  puts "#{element.type}: #{element.text.inspect}"
end
```

Parse a file instead:

```ruby
screenplay = FountainRB.parse_file("script.fountain")
```

## The object model

`FountainRB.parse` returns a `FountainRB::Screenplay`. It is `Enumerable` over
its `elements`, which appear in source order.

Every element offers:

| Method | Description |
| --- | --- |
| `#type` | A symbol such as `:scene_heading` or `:dialogue`. |
| `#text` | The element text, with the Fountain prefix removed but inline markup intact. |
| `#line` | 1-based source line where the element begins. |
| `#blank_before` | Number of blank source lines immediately before it. |
| `#forced?` | Whether the writer used an explicit prefix (`.`, `@`, `!`, `>` or `~`). |
| `#notes` | Inline note texts found in the element. |
| `#to_h` | A JSON-friendly hash. |

Element classes:

| Class | Type | Notes |
| --- | --- | --- |
| `SceneHeading` | `:scene_heading` | `#scene_number` for `#1A#` style numbers. |
| `Action` | `:action` | Multi-line; `#lines`. |
| `Character` | `:character` | `#name`, `#extensions`, `#extension`, `#dual?`. |
| `Parenthetical` | `:parenthetical` | `#content` without the parentheses. |
| `Dialogue` | `:dialogue` | Multi-line; `#lines`. |
| `Lyrics` | `:lyrics` | Multi-line. |
| `Transition` | `:transition` | |
| `Centered` | `:centered` | Fountain's centered text. |
| `PageBreak` | `:page_break` | |
| `Section` | `:section` | `#level` (number of `#`). |
| `Synopsis` | `:synopsis` | |
| `Note` | `:note` | A note on its own line. |

### Screenplay helpers

```ruby
screenplay.title_page     # TitlePage or nil
screenplay.elements       # Array<Element>
screenplay.scenes         # Array<SceneHeading> (alias: scene_headings)
screenplay.action         # Array<Action>
screenplay.characters     # Array<Character>
screenplay.character_names
screenplay.dialogues      # Array<Dialogue> (alias: dialogue)
screenplay.dialogue_blocks
screenplay.units          # elements + dialogue blocks + dual-dialogue pairs
screenplay.parentheticals
screenplay.lyrics
screenplay.transitions
screenplay.centered
screenplay.page_breaks
screenplay.sections
screenplay.synopses
screenplay.notes          # every note, standalone and inline
screenplay.boneyards      # the text of every /* ... */ comment
screenplay.of_type(:dialogue)
```

Dialogue is grouped into `DialogueBlock`s:

```ruby
block = screenplay.dialogue_blocks.first
block.character        # Character
block.parts            # Parentheticals, Dialogue and Notes
block.dialogue         # Array<Dialogue>
block.parentheticals   # Array<Parenthetical>
block.text             # all spoken text joined with newlines
block.dual?            # true when marked with ^
```

A caret on a cue pairs that block with the previous one. `screenplay.units`
returns a `FountainRB::DualDialogue` for such pairs, with `#left` and `#right`.
The flat `#elements` list still contains every element individually.

### Title page

```ruby
page = screenplay.title_page

page["title"]     #=> ["BRICK & STEEL", "FULL RETIRED"]
page.title        #=> ["BRICK & STEEL", "FULL RETIRED"]
page.fetch("title") #=> "BRICK & STEEL"
page.authors      # "Author" + "Authors"
page.credit
page.source
page.draft_date
page.contact
page.copyright
page.notes
page.keys
page.to_h
```

Keys are normalised to lowercase, and a key may appear more than once. Values
on following lines must be indented with three or more spaces or a tab.

## Inline markup

`FountainRB::Inline` parses and renders the markup that lives inside elements.
Fountain uses Markdown-style emphasis, except that underscores mean underline:

| Markup | Result |
| --- | --- |
| `*italics*` | `<em>italics</em>` |
| `**bold**` | `<strong>bold</strong>` |
| `***bold italics***` | `<strong><em>bold italics</em></strong>` |
| `_underline_` | `<u>underline</u>` |
| `[[a note]]` | a note (omitted from formatted output) |
| `\*escaped\*` | literal asterisks |

```ruby
FountainRB::Inline.to_html("_Steel's face FILLS the *scope*._")
#=> "<u>Steel&#39;s face FILLS the <em>scope</em>.</u>"

FountainRB::Inline.to_plain_text("A *very* good day.")
#=> "A very good day."

nodes = FountainRB::Inline.parse("A *very* good day.")
nodes.map(&:to_h)
```

Emphasis never crosses a line break, and a backslash escapes the following
markup character. Notes may span a single line break, but not a blank line.
Notes are omitted from rendered output unless you ask for them.

## Rendering

### HTML

```ruby
screenplay.to_html
# or
FountainRB::HTMLRenderer.new.render(screenplay)
```

Options:

```ruby
screenplay.to_html(
  notes: true,      # render notes (default: false)
  sections: true,   # render sections (default: false)
  synopses: true,   # render synopses (default: false)
  title_page: true, # render the title page (default: true)
  page_breaks: true # render page breaks (default: true)
)
```

The output uses semantic classes such as `.fountain`, `.title-page`,
`.scene-heading`, `.action`, `.dialogue-block`, `.character`, `.dialogue`,
`.parenthetical`, `.transition`, `.centered`, `.lyrics`, `.dual-dialogue`,
`.page-break`, `.section`, `.synopsis` and `.note`. Bring your own CSS.

### Plain text

```ruby
screenplay.to_plain_text
FountainRB::PlainTextRenderer.new(notes: true).render(screenplay)
```

This renderer is intentionally simple — it indents characters, dialogue and
parentheticals and does not wrap lines — but it is handy for smoke tests and
quick inspection.

### JSON

```ruby
screenplay.to_h
screenplay.to_json
require "json"
JSON.pretty_generate(screenplay.to_h)
```

## Validation

Fountain is deliberately forgiving: `FountainRB.parse` always succeeds and
falls back to Action for anything it does not understand. If you want to warn
writers about likely mistakes, use the validator:

```ruby
FountainRB.valid?(source)   #=> false

FountainRB.validate(source).each do |issue|
  puts "#{issue.line}: #{issue.severity}: #{issue.message}"
end

screenplay = FountainRB.parse(source)
screenplay.valid?
screenplay.issues
```

`valid?` is true when validation finds no issues. `validate` returns an array
of `FountainRB::Issue` objects, ordered by line. Each issue exposes `code`,
`message`, `line`, `severity` (`:error` or `:warning`), `error?`, `warning?`,
`to_h` and `to_s`.

| Code | Severity | Meaning |
| --- | --- | --- |
| `unclosed_boneyard` | error | A `/*` comment is never closed and swallows the rest of the file. |
| `unexpected_boneyard_close` | warning | A `*/` has no matching `/*`. |
| `unclosed_note` | error | A `[[` note is never closed. |
| `unexpected_note_close` | warning | A `]]` has no matching `[[`. |
| `note_spans_blank_line` | warning | A note crosses a true blank line, so it will not be parsed as a note (use a two-space line to connect it). |
| `malformed_scene_number` | warning | A scene heading ends with a `#` number that is missing its closing `#`. |
| `orphan_dual_dialogue` | warning | A `^` caret has no preceding dialogue block. |

Validation is conservative: it only reports problems that the parser would
otherwise silently recover from. In particular, emphasis is not validated,
because asterisks and underscores are common literal text.

## Command line interface

The gem ships with a `fountainrb` executable.

```sh
fountainrb script.fountain             # HTML
fountainrb --text script.fountain      # plain text
fountainrb --json script.fountain      # JSON AST
fountainrb --ast script.fountain       # human-readable element dump

fountainrb --notes --sections --synopses script.fountain
```

## Syntax coverage

| Fountain feature | Supported |
| --- | --- |
| Title page, multi-line values, arbitrary keys | ✅ |
| Scene headings (`INT`, `EXT`, `EST`, `INT./EXT`, `INT/EXT`, `I/E`, plus `EXT/INT`) | ✅ |
| Forced scene headings (`.`) and scene numbers (`#1A#`) | ✅ |
| Action, forced action (`!`), indentation, tabs, vertical whitespace | ✅ |
| Character cues, extensions, forced cues (`@`) | ✅ |
| Dialogue, multi-line dialogue, two-space blank lines | ✅ |
| Parentheticals | ✅ |
| Dual dialogue (`^`) | ✅ |
| Lyrics (`~`) | ✅ |
| Transitions (`... TO:` and forced `>`) | ✅ |
| Centered text (`> ... <`) | ✅ |
| Emphasis (`*`, `**`, `***`, `_`) | ✅ |
| Escaping with backslashes | ✅ |
| Page breaks (`===`) | ✅ |
| Sections (`#`) and synopses (`=`) | ✅ |
| Notes (`[[...]]`), inline and multi-line | ✅ |
| Boneyards (`/* ... */`), inline and multi-line | ✅ |
| Punctuation is left exactly as written | ✅ |

Error handling follows Fountain's philosophy: when in doubt, return the text as
Action. Unclosed emphasis, notes, and boneyards are handled gracefully —
unclosed boneyards comment out the remainder of the file.

### Implementation notes

* Boneyards are removed before parsing. A multi-line boneyard is replaced by
  the same number of newlines, which keeps source line numbers accurate and
  lets the comment behave as whitespace. The removed text is available through
  `screenplay.boneyards`.
* A line consisting of two or more spaces keeps dialogue open and produces an
  empty line inside the dialogue, as described by the spec. Outside dialogue it
  is treated as a normal blank line.
* Sections, synopses and standalone notes are ignored in formatted output and
  do not disturb the blank-line context used to classify the following line.
* Centered text is exposed as its own `:centered` element rather than being
  indistinguishable from Action.
* In addition to the scene-heading prefixes listed by the spec, `EXT/INT` and
  `EXT./INT.` are recognised, because they appear in real screenplays (such as
  the official Big Fish sample).

## Development

```sh
bundle install
bundle exec rake          # run the specs
bundle exec rspec         # run the specs directly
bundle exec rake doc      # documentation formatter
bundle exec rake console  # IRB with fountainrb loaded
```

The test suite contains 500+ examples covering every element type, inline
markup, validation, edge cases, both renderers, the CLI, and two full
integration fixtures.

## License

fountainrb is available under the MIT license. See [LICENSE.txt](LICENSE.txt).
