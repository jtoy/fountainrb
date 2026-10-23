# frozen_string_literal: true

RSpec.describe FountainRB do
  it "has a semantic version" do
    expect(FountainRB::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end

  it "exposes a parse method" do
    screenplay = FountainRB.parse("INT. HOUSE - DAY")
    expect(screenplay).to be_a(FountainRB::Screenplay)
  end

  it "parses files from disk" do
    path = File.expand_path("../fixtures/brick_and_steel.fountain", __dir__)
    screenplay = FountainRB.parse_file(path)
    expect(screenplay.scenes).not_to be_empty
  end

  it "normalises CRLF line endings" do
    screenplay = FountainRB.parse("STEEL\r\nHello.\r\n")
    expect(types(screenplay)).to eq(%i[character dialogue])
    expect(screenplay.first.name).to eq("STEEL")
  end

  it "strips a UTF-8 byte order mark" do
    screenplay = FountainRB.parse("\uFEFFINT. HOUSE - DAY")
    expect(screenplay.first).to be_a(FountainRB::SceneHeading)
  end
end
