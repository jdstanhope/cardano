require "test_helper"

class PaytablesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @game = games(:five_by_three)
    @variation = variations(:ninety_six)
    @ace = game_symbols(:ace)
    @king = game_symbols(:king)
    sign_in_as @game.user
  end

  def update(payouts)
    patch game_variation_paytable_url(@game, @variation), params: { payouts: payouts }
  end

  test "the grid covers every symbol against every reachable count" do
    get game_variation_url(@game, @variation)

    assert_response :success
    assert_select "[data-paytable] input[name=?]", "payouts[#{@ace.id}][3]"
    assert_select "[data-paytable] input[name=?]", "payouts[#{@ace.id}][#{@game.reel_count}]"
    assert_select "[data-paytable] input[name=?]", "payouts[#{@ace.id}][#{@game.reel_count + 1}]", false,
      "a five reel game cannot show six of a kind"
  end

  test "saves the whole grid at once" do
    update(@king.id.to_s => { "3" => "4", "4" => "20", "5" => "80" })

    assert_redirected_to game_variation_url(@game, @variation)
    entries = @variation.paytable_entries.where(game_symbol: @king).order(:count)
    assert_equal [ [ 3, 4 ], [ 4, 20 ], [ 5, 80 ] ], entries.map { |e| [ e.count, e.payout ] }
  end

  test "a blank cell means the combination does not pay" do
    update(@ace.id.to_s => { "3" => "", "4" => "25" })

    assert_nil @variation.paytable_entries.find_by(game_symbol: @ace, count: 3)
    assert_equal 25, @variation.paytable_entries.find_by(game_symbol: @ace, count: 4).payout
  end

  test "clearing a cell removes the entry that was there" do
    existing = @variation.paytable_entries.find_by(game_symbol: @ace, count: 3)
    assert existing

    update(@ace.id.to_s => { "3" => "" })

    assert_nil @variation.paytable_entries.reload.find_by(game_symbol: @ace, count: 3)
  end

  test "a payout must be a positive whole number, reported against its cell" do
    update(@king.id.to_s => { "3" => "0" })

    assert_response :unprocessable_entity
    assert_select "[data-payout-error='#{@king.id}-3']"
  end

  test "nothing is saved when any cell is rejected" do
    before = @variation.paytable_entries.reload.map { |e| [ e.game_symbol_id, e.count, e.payout ] }.sort

    update(@king.id.to_s => { "3" => "4" }, @ace.id.to_s => { "3" => "-1" })

    assert_response :unprocessable_entity
    assert_equal before, @variation.paytable_entries.reload.map { |e| [ e.game_symbol_id, e.count, e.payout ] }.sort,
      "a rejected save must leave the whole paytable as it was"
  end

  test "a symbol from another game cannot be paid for" do
    update(game_symbols(:foreign_ace).id.to_s => { "3" => "5" })

    assert_response :unprocessable_entity
    assert_nil @variation.paytable_entries.reload.find_by(game_symbol_id: game_symbols(:foreign_ace).id)
  end

  test "another person's variation cannot be written to" do
    patch game_variation_paytable_url(games(:other_game), @variation), params: { payouts: {} }

    assert_response :not_found
  end
end
