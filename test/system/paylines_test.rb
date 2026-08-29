require "application_system_test_case"

class PaylinesTest < ApplicationSystemTestCase
  setup do
    @game = users(:one).games.create!(name: "Line Work", reel_count: 5, row_count: 3)
    sign_in_through_the_form(users(:one))
  end

  # The flow moved off the game page, and every control on it submits a form. Whether
  # those still reach the right place is exactly what a browser proves and an
  # integration test assumes.
  test "paylines are reached from the game page, applied, and removed" do
    visit game_path(@game)

    assert_text "No paylines yet"
    click_on "Edit paylines"

    assert_selector "h1", text: "Paylines"

    click_on "9 lines"
    assert_text "Applied the 9 lines set"
    assert_selector "[data-payline]", count: 9

    within first("[data-payline]") do
      accept_confirm { click_on "Remove" }
    end

    assert_text "removed"
    assert_selector "[data-payline]", count: 8

    # The game page counts what the paylines page holds.
    click_on @game.name
    assert_text "8 lines"
  end
end
