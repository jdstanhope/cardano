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
    assert_text "9 combinations here"
  end

  test "a combination can be removed from the page" do
    visit game_variation_path(@game, @variation)
    entry = @variation.paytable.find { |e| e.sequence == %w[ R7 W7 B7 ] }

    within "[data-combination='#{entry.id}']" do
      click_on "Remove"
    end

    assert_text "Removed R7 W7 B7"
    assert_text "7 combinations here"
  end

  # A row edited into the same symbol repeated belongs in the grid. It leaves this list,
  # which without saying so would read as having lost the edit.
  test "a row that becomes N-of-a-kind moves to the grid, and says so" do
    entry = @variation.paytable.find { |e| e.sequence == %w[ R7 W7 B7 ] }
    visit game_variation_path(@game, @variation)

    within "[data-combination='#{entry.id}']" do
      all("select")[1].select "R7"
      all("select")[2].select "R7"
      click_on "Save"
    end

    assert_text "edited in the grid above"
    assert_no_selector "[data-combination='#{entry.id}']"
    assert_equal %w[ R7 R7 R7 ], entry.reload.matchers.reload.map(&:label)
  end
end
