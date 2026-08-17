# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "standard/rake"

RSpec::Core::RakeTask.new(:spec)

desc "Generate YARD documentation"
task :doc do
  sh "bundle exec yard doc"
end

task default: %i[spec standard]
