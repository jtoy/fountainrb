# frozen_string_literal: true

RSpec.describe "Parsing parentheticals" do
  it "parses a parenthetical after a character" do
    screenplay = parse("STEEL\n(starting the engine)\nSo much for retirement!")
    expect(types(screenplay)).to eq(%i[character parenthetical dialogue])
    element = screenplay[1]
    expect(element).to be_a(FountainRB::Parenthetical)
    expect(element.text).to eq("(starting the engine)")
    expect(element.content).to eq("starting the engine")
  end

  it "parses a parenthetical after dialogue" do
    screenplay = parse("STEEL\nHi.\n(pause)\nBye.")
    expect(types(screenplay)).to eq(%i[character dialogue parenthetical dialogue])
  end

  it "parses consecutive parentheticals" do
    screenplay = parse("STEEL\n(whispering)\n(urgently)\nGo!")
    expect(types(screenplay)).to eq(%i[character parenthetical parenthetical dialogue])
  end

  it "includes the parentheses in the text" do
    expect(parse("STEEL\n(oh crap)\nHello...")[1].text).to eq("(oh crap)")
  end

  it "strips the parentheses in #content" do
    expect(parse("STEEL\n(oh crap)\nHello...")[1].content).to eq("oh crap")
  end

  it "ignores indentation" do
    screenplay = parse("STEEL\n    (whispering)\nGo!")
    expect(screenplay[1].text).to eq("(whispering)")
  end

  it "is action when it does not follow dialogue" do
    screenplay = parse("(whispering)")
    expect(types(screenplay)).to eq([:action])
  end

  it "is dialogue when the closing parenthesis is missing" do
    screenplay = parse("STEEL\n(whispering\nHi.")
    expect(types(screenplay)).to eq(%i[character dialogue])
    expect(screenplay.last.text).to eq("(whispering\nHi.")
  end

  it "keeps markup inside a parenthetical" do
    screenplay = parse("STEEL\n(*quietly*)\nHi.")
    expect(screenplay[1].text).to eq("(*quietly*)")
  end

  it "serialises the content" do
    hash = parse("STEEL\n(oh crap)\nHello...")[1].to_h
    expect(hash["type"]).to eq("parenthetical")
    expect(hash["content"]).to eq("oh crap")
  end
end
