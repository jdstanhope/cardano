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

  test "every combination has a row, including the ones the grid cannot express" do
    get game_variation_url(@game, @variation)

    assert_response :success
    assert_select "[data-combination]", 15

    @variation.paytable.each do |entry|
      assert_select "[data-combination='#{entry.id}']", 1, "#{entry.sequence.join(" ")} has no row"
    end
  end

  test "the top prize, which mixes three symbols, is on the page with its payout" do
    top = @variation.paytable.max_by(&:payout)
    assert_equal %w[ R7 W7 B7 ], top.sequence

    get game_variation_url(@game, @variation)

    assert_select "[data-combination='#{top.id}'] input[name=payout][value=?]", "2400"
  end

  test "a group position is selected as that group" do
    sevens = @game.symbol_groups.find_by(name: "Sevens")
    entry = @variation.paytable.find { |e| e.sequence == [ "Sevens" ] * 3 }

    get game_variation_url(@game, @variation)

    assert_select "[data-combination='#{entry.id}'] option[selected][value=?]", "group:#{sevens.id}", count: 3
  end

  test "it says how many combinations there are, and how many the grid also reaches" do
    get game_variation_url(@game, @variation)

    assert_match(/15 combinations, of which\s+7 are the same symbol repeated/,
                 css_select("[data-paytable]").first.text)
  end

  test "a variation with nothing in its paytable still offers a way to add one" do
    empty = @game.variations.create!(number: 2)

    get game_variation_url(@game, empty)

    assert_response :success
    assert_select "[data-combination]", 0
    assert_match(/Nothing pays yet/, css_select("[data-paytable]").first.text)
    assert_select "form[action=?]", game_variation_combinations_path(@game, empty)
  end
end
