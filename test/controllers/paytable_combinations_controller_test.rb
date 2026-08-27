require "test_helper"

class PaytableCombinationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @game = SampleGame::RedWhiteAndBlue.build_for(users(:one))
    @variation = @game.variations.first
    @red, @white, @blue = %w[ R7 W7 B7 ].map { |code| @game.symbols.find_by(code: code) }
    @sevens = @game.symbol_groups.find_by(name: "Sevens")
    sign_in_as users(:one)
  end

  def token(thing) = thing.is_a?(SymbolGroup) ? "group:#{thing.id}" : "symbol:#{thing.id}"

  test "a combination mixing different symbols can be added" do
    assert_difference -> { @variation.paytable_entries.count }, 1 do
      post game_variation_combinations_url(@game, @variation),
        params: { payout: 300, sequence: [ token(@white), token(@blue), token(@red) ] }
    end

    assert_redirected_to game_variation_url(@game, @variation)
    added = @variation.paytable.max_by(&:id)
    assert_equal %w[ W7 B7 R7 ], added.sequence
    assert_equal 300, added.payout
  end

  test "a combination naming a group can be added" do
    post game_variation_combinations_url(@game, @variation),
      params: { payout: 60, sequence: [ token(@sevens), token(@sevens) ] }

    added = @variation.paytable.max_by(&:id)
    assert_equal [ "Sevens", "Sevens" ], added.sequence
    assert_equal @sevens, added.matchers.first.symbol_group
  end

  test "a shorter combination is allowed, and stops where it stops" do
    post game_variation_combinations_url(@game, @variation),
      params: { payout: 4, sequence: [ token(@red), token(@red), "" ] }

    assert_equal %w[ R7 R7 ], @variation.paytable.max_by(&:id).sequence
  end

  # "R7, nothing, W7" is almost certainly a half-finished edit. Closing the gap would
  # save a two-symbol combination nobody described.
  test "a gap is refused rather than closed up" do
    assert_no_difference -> { @variation.paytable_entries.count } do
      post game_variation_combinations_url(@game, @variation),
        params: { payout: 4, sequence: [ token(@red), "", token(@white) ] }
    end

    assert_equal "A combination cannot have a gap. Fill the positions from the left.", flash[:alert]
  end

  test "the order of an existing combination can be changed" do
    entry = @variation.paytable.find { |e| e.sequence == %w[ R7 W7 B7 ] }

    patch game_variation_combination_url(@game, @variation, entry),
      params: { payout: entry.payout, sequence: [ token(@blue), token(@white), token(@red) ] }

    assert_equal %w[ B7 W7 R7 ], entry.reload.matchers.reload.map(&:label)
  end

  test "a payout can be changed without touching the sequence" do
    entry = @variation.paytable.find { |e| e.sequence == [ "Sevens", "Sevens", "Sevens" ] }

    patch game_variation_combination_url(@game, @variation, entry),
      params: { payout: 90, sequence: entry.matchers.map { |m| token(m.symbol_group || m.game_symbol) } }

    assert_equal 90, entry.reload.payout
    assert_equal [ "Sevens", "Sevens", "Sevens" ], entry.matchers.reload.map(&:label)
  end

  test "a combination can be removed" do
    entry = @variation.paytable.find { |e| e.sequence == [ "Bars", "Bars", "Bars" ] }

    assert_difference -> { @variation.paytable_entries.count }, -1 do
      delete game_variation_combination_url(@game, @variation, entry)
    end

    assert_equal 0, PaytableMatcher.where(paytable_entry_id: entry.id).count, "its matchers went with it"
  end

  test "a rejected edit leaves the combination as it was" do
    entry = @variation.paytable.find { |e| e.sequence == %w[ R7 R7 R7 ] }

    patch game_variation_combination_url(@game, @variation, entry),
      params: { payout: 0, sequence: [ token(@red), token(@red), token(@red) ] }

    entry.reload
    assert_equal 1199, entry.payout
    assert_equal %w[ R7 R7 R7 ], entry.matchers.reload.map(&:label)
    assert_match(/greater than 0/, flash[:alert])
  end

  test "one position is not a combination" do
    assert_no_difference -> { @variation.paytable_entries.count } do
      post game_variation_combinations_url(@game, @variation), params: { payout: 5, sequence: [ token(@red) ] }
    end

    assert_match(/at least 2/, flash[:alert])
  end

  test "a symbol from another game is not in this one" do
    theirs = games(:other_game).symbols.create!(code: "ZZ", name: "Theirs", position: 1)

    assert_no_difference -> { @variation.paytable_entries.count } do
      post game_variation_combinations_url(@game, @variation),
        params: { payout: 5, sequence: [ "symbol:#{theirs.id}", "symbol:#{theirs.id}" ] }
    end

    assert_equal "That combination names something that is not in this game.", flash[:alert]
  end

  test "another person's variation is not found" do
    theirs = users(:two).games.create!(name: "Theirs", reel_count: 3, row_count: 1)
    assert_not_equal theirs.user, users(:one)

    assert_no_difference -> { PaytableEntry.count } do
      post game_variation_combinations_url(theirs, theirs.variations.first),
        params: { payout: 5, sequence: [] }
    end

    assert_response :not_found
  end

  test "signing in is required" do
    reset!

    post game_variation_combinations_url(@game, @variation), params: { payout: 5, sequence: [] }

    assert_redirected_to new_session_url
  end

  # The whole point: a paytable the interface can express in full computes the figure
  # the machine is published as returning.
  test "the sample stays at its published figure through an edit and back" do
    entry = @variation.paytable.find { |e| e.sequence == %w[ R7 W7 B7 ] }
    before = @variation.rtp.value

    patch game_variation_combination_url(@game, @variation, entry),
      params: { payout: 5000, sequence: [ token(@red), token(@white), token(@blue) ] }
    assert_not_equal before, @variation.reload.rtp.value

    patch game_variation_combination_url(@game, @variation, entry),
      params: { payout: 2400, sequence: [ token(@red), token(@white), token(@blue) ] }
    assert_equal before, @variation.reload.rtp.value
  end
end
