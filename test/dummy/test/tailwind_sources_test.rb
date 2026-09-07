# frozen_string_literal: true

require "test_helper"

class TailwindSourcesTest < ActiveSupport::TestCase
  test "dummy tailwind scans installed FlatPack components and Recording Studio views" do
    css = File.read(Rails.root.join("app/assets/tailwind/application.css"))

    assert_includes css, "/usr/local/lib/ruby/gems/*/bundler/gems/flatpack-"
    assert_includes css, "/usr/local/lib/ruby/gems/*/bundler/gems/RecordingStudio-"
  end

  test "built tailwind includes icon-only button padding used by core PageNav" do
    built = File.read(Rails.root.join("app/assets/builds/tailwind.css"))

    assert_includes built, "--button-icon-only-padding-md"
  end
end
