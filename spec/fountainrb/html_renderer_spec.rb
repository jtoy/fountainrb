# frozen_string_literal: true

RSpec.describe FountainRB::HTMLRenderer do
  let(:source) do
    <<~FOUNTAIN
      Title: My Script
      Author: A. Writer

      INT. HOUSE - DAY #1#

      An *action* line.

      STEEL (V.O.)
      (whispering)
      Hello.

      BRICK ^
      Hi.

      CUT TO:

      ~La la

      > THE END <

      ===

      # Section

      = Synopsis

      [[a note]]
    FOUNTAIN
  end

  subject(:html) { parse(source).to_html }

  it "wraps the output in a fountain container" do
    expect(html).to start_with(%(<div class="fountain">))
    expect(html).to end_with("</div>")
  end

  it "renders the title page" do
    expect(html).to include('<section class="title-page">')
    expect(html).to include('<div class="title">')
    expect(html).to include("<p>My Script</p>")
    expect(html).to include('<div class="author">')
  end

  it "renders a scene heading with its scene number" do
    expect(html).to include(
      '<h2 class="scene-heading" data-scene-number="1">INT. HOUSE - DAY</h2>'
    )
  end

  it "renders action with emphasis" do
    expect(html).to include('<p class="action">An <em>action</em> line.</p>')
  end

  it "renders a dialogue block" do
    expect(html).to include('<div class="dialogue-block">')
    expect(html).to include('<p class="character">')
    expect(html).to include('<span class="character-name">STEEL</span>')
    expect(html).to include('<span class="extension">(V.O.)</span>')
    expect(html).to include('<p class="parenthetical">(whispering)</p>')
    expect(html).to include('<p class="dialogue">Hello.</p>')
  end

  it "renders dual dialogue" do
    expect(html).to include('<div class="dual-dialogue">')
    expect(html).to include('<span class="character-name">BRICK</span>')
  end

  it "renders transitions" do
    expect(html).to include('<p class="transition">CUT TO:</p>')
  end

  it "renders lyrics" do
    expect(html).to include('<p class="lyrics">La la</p>')
  end

  it "renders centered text" do
    expect(html).to include('<p class="centered">THE END</p>')
  end

  it "renders page breaks" do
    expect(html).to include('<div class="page-break"></div>')
  end

  it "omits sections, synopses and notes by default" do
    expect(html).not_to include('class="section"')
    expect(html).not_to include('class="synopsis"')
    expect(html).not_to include('class="note"')
  end

  it "can include sections" do
    expect(parse(source).to_html(sections: true)).to include(
      '<div class="section" data-level="1">Section</div>'
    )
  end

  it "can include synopses" do
    expect(parse(source).to_html(synopses: true)).to include(
      '<div class="synopsis">Synopsis</div>'
    )
  end

  it "can include standalone notes" do
    expect(parse(source).to_html(notes: true)).to include('<div class="note">a note</div>')
  end

  it "can include a note inside a dialogue block" do
    screenplay = parse("STEEL\n[[block note]]\nHello.")
    html = screenplay.to_html(notes: true)
    expect(html).to include('<p class="note">block note</p>')
    expect(html).to include('<p class="dialogue">Hello.</p>')
  end

  it "can omit page breaks" do
    expect(parse(source).to_html(page_breaks: false)).not_to include('class="page-break"')
  end

  it "can omit the title page" do
    expect(parse(source).to_html(title_page: false)).not_to include('class="title-page"')
  end

  it "renders inline notes only when asked" do
    screenplay = parse("A [[note]] B.")
    expect(screenplay.to_html).to include('<p class="action">A  B.</p>')
    expect(screenplay.to_html(notes: true)).to include(
      '<p class="action">A <span class="note">note</span> B.</p>'
    )
  end

  it "escapes HTML in text" do
    expect(parse("5 < 6 & 7 > 4").to_html).to include(
      '<p class="action">5 &lt; 6 &amp; 7 &gt; 4</p>'
    )
  end

  it "escapes quotes in attributes" do
    screenplay = parse(".A \"quoted\" heading #1#")
    expect(screenplay.to_html).to include('data-scene-number="1"')
  end

  it "does not render a title page when there is none" do
    expect(parse("Action.").to_html).not_to include('class="title-page"')
  end

  it "renders an empty screenplay as an empty container" do
    expect(parse("").to_html).to eq(%(<div class="fountain">\n\n</div>))
  end
end
