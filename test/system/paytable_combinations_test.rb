require "application_system_test_case"

class PaytableCombinationsTest < ApplicationSystemTestCase
  setup do
    @game = SampleGame::RedWhiteAndBlue.build_for(users(:one))
    @variation = @game.variations.first
    sign_in_through_the_form(users(:one))
  end

  test "a combination naming a group can be added from the page" do
    visit game_variation_path(@game, @variation)

    within "form[action='#{game_variation_combinations_path(@game, @variation)}']" do
      selects = all("select")
      selects[0].select "any Sevens"
      selects[1].select "any Bars"
      fill_in "payout_new", with: "12"
      click_on "Add"
    end

    assert_text "Added Sevens Bars"
    assert_text "16 combinations"
  end

  test "a combination can be removed from the page" do
    visit game_variation_path(@game, @variation)
    entry = @variation.paytable.find { |e| e.sequence == %w[ R7 W7 B7 ] }

    within "[data-combination='#{entry.id}']" do
      click_on "Remove"
    end

    assert_text "Removed R7 W7 B7"
    assert_text "14 combinations"
  end
end
