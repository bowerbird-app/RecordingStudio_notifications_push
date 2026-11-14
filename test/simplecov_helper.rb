# frozen_string_literal: true

return if ENV["DISABLE_SIMPLECOV"] == "true"

begin
  require "simplecov"
rescue LoadError
  return
end

# Gem tests and the dummy app are separate processes. Each process gets its own
# command name so SimpleCov merges them into one app/ + lib/ report.
engine_root = File.expand_path("..", __dir__)

SimpleCov.start do
  root engine_root
  coverage_dir File.join(engine_root, "coverage")
  command_name "suite-#{Process.pid}"
  merge_timeout 3600
  enable_coverage :branch
  track_files "{app,lib}/**/*.rb"
  add_filter "/test/"
  add_filter "/config/"
  add_filter "/db/"
  add_filter do |source|
    !source.filename.start_with?("#{engine_root}/")
  end
end
