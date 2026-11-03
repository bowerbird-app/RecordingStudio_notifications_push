# frozen_string_literal: true

require "application_system_test_case"

class ThemeMenuSystemTest < ApplicationSystemTestCase
  setup do
    User.find_or_create_by!(email: "admin@admin.com") do |user|
      user.password = "Password"
      user.password_confirmation = "Password"
    end
  end

  test "open cog menu is opaque on the first frame" do
    visit new_user_session_path
    fill_in "user[email]", with: "admin@admin.com"
    fill_in "user[password]", with: "Password"
    click_button "Sign In"

    assert_selector ".dummy-theme-selector"
    find(".dummy-theme-selector button").click
    assert_selector "[data-flat-pack--button-dropdown-target='menu'] [data-controller~='dummy-theme-menu']", visible: :visible

    reading = page.evaluate_script(<<~JS)
      (() => {
        const menu = document.querySelector("[data-flat-pack--button-dropdown-target='menu']:has([data-controller~='dummy-theme-menu'])")
        const style = getComputedStyle(menu)
        const canvas = document.createElement("canvas")
        canvas.width = 1
        canvas.height = 1
        const context = canvas.getContext("2d")
        context.fillStyle = "#000000"
        context.fillStyle = style.backgroundColor
        context.fillRect(0, 0, 1, 1)
        const pixel = context.getImageData(0, 0, 1, 1).data
        return {
          opacity: style.opacity,
          alpha: pixel[3],
          transitionDuration: style.transitionDuration
        }
      })()
    JS

    assert_equal "1", reading.fetch("opacity"), reading.inspect
    assert_equal 255, reading.fetch("alpha"), reading.inspect
    assert_match(/\A0s(, 0s)*\z/, reading.fetch("transitionDuration"), reading.inspect)
  end
end
