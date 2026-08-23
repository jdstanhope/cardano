require "application_system_test_case"

class ReelStripsTest < ApplicationSystemTestCase
  setup do
    @game = games(:five_by_three)
    @variation = variations(:ninety_six)
    sign_in_through_the_form @game.user
  end

  test "counts the stops and symbols as a reel is typed" do
    visit game_variation_path(@game, @variation)
    assert_selector "h1", text: "Variation"

    fill_in "Reel 3", with: "A K K Q Q Q"

    # The count is produced by JavaScript; nothing on the server sees this until save.
    within(:xpath, "//textarea[@id='reel_3']/ancestor::div[@data-controller='reel-count']") do
      assert_text "6 stops"
      assert_text "Q 3"
      assert_text "K 2"
      assert_text "A 1"
    end
  end

  test "saves every reel together" do
    visit game_variation_path(@game, @variation)
    assert_selector "h1", text: "Variation"

    fill_in "Reel 4", with: "A A K"
    fill_in "Reel 5", with: "Q Q J"
    click_on "Save reels"

    assert_text "Reels saved"
    assert_equal %w[ A A K ], @variation.reel_strips.find_by(position: 4).symbols
    assert_equal %w[ Q Q J ], @variation.reel_strips.find_by(position: 5).symbols
  end

  test "an unknown code is reported against its reel and the typing is kept" do
    visit game_variation_path(@game, @variation)
    assert_selector "h1", text: "Variation"

    fill_in "Reel 2", with: "A ZZ K"
    click_on "Save reels"

    assert_text "ZZ is not a symbol in this game"
    # A rejected save must not throw away what was typed.
    assert_field "Reel 2", with: "A ZZ K"
  end
end
