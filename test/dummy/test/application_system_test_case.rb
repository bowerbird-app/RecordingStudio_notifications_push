# frozen_string_literal: true

require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 390, 844 ] do |options|
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--force-color-profile=srgb")

    binary = ENV["CHROME_BIN"].presence
    binary ||= %w[/usr/bin/google-chrome /usr/bin/google-chrome-stable /usr/local/bin/google-chrome].find { |path| File.exist?(path) }
    options.binary = binary if binary
  end
end
