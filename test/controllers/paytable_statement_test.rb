require "test_helper"

# The page reports a figure computed from every combination, so it has to show every
# combination. Showing part of a paytable that reads as the whole of one is worse than
# showing none: it is wrong rather than missing, and silently so.
class PaytableStatementTest < ActionDispatch::IntegrationTest
  setup do
    @game = SampleGame::RedWhiteAndBlue.build_for(users(:one))
    @variation = @game.variations.first
    sign_in_as users(:one)
  end

  test "every combination appears, including the ones the grid cannot express" do
    get game_variation_url(@game, @variation)

    assert_response :success
    shown = css_select("[data-paytable]").first.text

    # The top prize mixes three different symbols, so it has no cell in the grid.
    assert_match(/2,400/, shown, "the top prize is invisible")

    %w[ Sevens Bars Reds Whites Blues ].each do |group|
      assert_match(/#{group}/, shown, "the #{group} combinations are invisible")
    end

    # And the ones the grid does reach are still there, so this is the whole paytable.
    assert_match(/1,199/, shown)
  end

  test "it says how many combinations there are, and how many the grid reaches" do
    get game_variation_url(@game, @variation)

    assert_match(/15 combinations, of which\s+7 can be edited in the grid/, css_select("[data-paytable]").first.text)
  end

  test "a variation with nothing in its paytable says so" do
    empty = @game.variations.create!(number: 2)

    get game_variation_url(@game, empty)

    assert_response :success
    assert_match(/Nothing pays yet/, css_select("[data-paytable]").first.text)
  end
end
