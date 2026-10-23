# frozen_string_literal: true

require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

desc "Run the specs with documentation output"
task :doc do
  sh "bundle exec rspec --format documentation"
end

desc "Open an IRB session with fountainrb loaded"
task :console do
  sh "irb -Ilib -rfountainrb"
end

task default: :spec
