# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "fountainrb"

module FountainHelpers
  # Parse a Fountain string.
  def parse(source)
    FountainRB.parse(source)
  end

  # Element type symbols in order.
  def types(screenplay)
    screenplay.elements.map(&:type)
  end

  # Element texts in order.
  def texts(screenplay)
    screenplay.elements.map(&:text)
  end

  # Load a fixture from spec/fixtures.
  def fixture(name)
    File.read(File.expand_path("fixtures/#{name}", __dir__), encoding: "UTF-8")
  end

  # Names of the classes of all elements (useful for readability assertions).
  def classes(screenplay)
    screenplay.elements.map { |element| element.class.name.split("::").last }
  end
end

RSpec.configure do |config|
  config.include FountainHelpers

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed

  config.filter_run_when_matching :focus
end
