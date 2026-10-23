# frozen_string_literal: true

require "json"
require "open3"
require "rbconfig"

RSpec.describe "fountainrb command line interface" do
  def root
    File.expand_path("../..", __dir__)
  end

  def exe
    File.join(root, "exe", "fountainrb")
  end

  def fixture_path
    File.join(root, "spec", "fixtures", "features.fountain")
  end

  def run(*args)
    Open3.capture3(RbConfig.ruby, "-I", File.join(root, "lib"), exe, *args)
  end

  it "prints the version" do
    stdout, stderr, status = run("--version")
    expect(status).to be_success
    expect(stdout.strip).to eq(FountainRB::VERSION)
    expect(stderr).to be_empty
  end

  it "prints help" do
    stdout, _stderr, status = run("--help")
    expect(status).to be_success
    expect(stdout).to include("Usage: fountainrb")
    expect(stdout).to include("--json")
  end

  it "renders HTML by default" do
    stdout, _stderr, status = run(fixture_path)
    expect(status).to be_success
    expect(stdout).to include('<div class="fountain">')
    expect(stdout).to include("INT. LAB - NIGHT")
  end

  it "renders plain text with --text" do
    stdout, _stderr, status = run("--text", fixture_path)
    expect(status).to be_success
    expect(stdout).to include("INT. LAB - NIGHT")
    expect(stdout).to include("STEEL")
  end

  it "renders JSON with --json" do
    stdout, _stderr, status = run("--json", fixture_path)
    expect(status).to be_success
    parsed = JSON.parse(stdout)
    expect(parsed["title_page"]["title"]).to eq(["Fountain Features"])
    expect(parsed["elements"]).to be_an(Array)
  end

  it "prints an AST with --ast" do
    stdout, _stderr, status = run("--ast", fixture_path)
    expect(status).to be_success
    expect(stdout).to include("scene_heading")
    expect(stdout).to include("INT. LAB - NIGHT")
  end

  it "includes optional elements when asked" do
    stdout, _stderr, status = run("--notes", "--sections", "--synopses", fixture_path)
    expect(status).to be_success
    expect(stdout).to include("Check the spelling.")
    expect(stdout).to include("Act One")
    expect(stdout).to include("Establish the world.")
  end

  it "fails when the file does not exist" do
    _stdout, stderr, status = run("does-not-exist.fountain")
    expect(status.exitstatus).to eq(1)
    expect(stderr).to include("no such file")
  end

  it "fails when no file is given" do
    _stdout, stderr, status = run
    expect(status.exitstatus).to eq(1)
    expect(stderr).to include("no input file")
  end

  it "fails on an unknown option" do
    _stdout, stderr, status = run("--nope", fixture_path)
    expect(status.exitstatus).to eq(1)
    expect(stderr).to include("invalid option")
  end
end
