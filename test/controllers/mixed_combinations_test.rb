require "test_helper"

# The page reports a figure computed from every combination, so every combination has
# to be reachable. The grid holds the same symbol repeated and this list holds the rest,
# so the two together are the whole paytable and neither overlaps the other.
class MixedCombinationsTest < ActionDispatch::IntegrationTest
  setup do
    @game = SampleGame::RedWhiteAndBlue.build_for(users(:one))
    @variation = @game.variations.first
    sign_in_as users(:one)
  end

  # Eight of the sample's fifteen mix symbols or name a group. The other seven are in
  # the grid, and must not also be here.
  test "the combinations the grid cannot express each have a row" do
    get game_variation_url(@game, @variation)

    assert_response :success
    assert_select "[data-combination]", 8

    @variation.paytable.reject(&:n_of_a_kind?).each do |entry|
      assert_select "[data-combination='#{entry.id}']", 1, "#{entry.sequence.join(" ")} has no row"
    end
  end

  test "an N-of-a-kind combination is edited in the grid and nowhere else" do
    get game_variation_url(@game, @variation)

    @variation.paytable.select(&:n_of_a_kind?).each do |entry|
      assert_select "[data-combination='#{entry.id}']", 0,
        "#{entry.sequence.join(" ")} is editable in two places"
    end

    # It is still on the page, in the grid, so nothing has become unreachable.
    red = @game.symbols.find_by(code: "R7")
    assert_select "input[name=?][value=?]", "payouts[#{red.id}][3]", "1199"
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

  test "it accounts for the whole paytable across both parts" do
    get game_variation_url(@game, @variation)

    assert_match(/8 combinations here, and\s+7 in the grid above:\s+15 combinations in total/,
                 css_select("[data-paytable]").first.text)
  end

  test "a variation with nothing in its paytable still offers a way to add one" do
    empty = @game.variations.create!(number: 2)

    get game_variation_url(@game, empty)

    assert_response :success
    assert_select "[data-combination]", 0
    assert_match(/None yet/, css_select("[data-paytable]").first.text)
    assert_select "form[action=?]", game_variation_combinations_path(@game, empty)
  end
end
