require "test_helper"

class GameSymbolsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @game = games(:five_by_three)
    sign_in_as @game.user
  end

  test "adds a symbol to the game" do
    assert_difference -> { @game.symbols.count }, 1 do
      post game_symbols_url(@game), params: { game_symbol: { code: "W", name: "Wild" } }
    end

    assert_redirected_to game_url(@game)
    assert_equal "W", @game.symbols.order(:position).last.code
  end

  test "a new symbol goes after the existing ones" do
    highest = @game.symbols.maximum(:position)

    post game_symbols_url(@game), params: { game_symbol: { code: "W" } }

    assert_equal highest + 1, @game.symbols.find_by(code: "W").position
  end

  test "reports a duplicate code rather than silently ignoring it" do
    assert_no_difference -> { @game.symbols.count } do
      post game_symbols_url(@game), params: { game_symbol: { code: game_symbols(:ace).code } }
    end

    assert_response :unprocessable_entity
  end

  test "removes an unused symbol" do
    unused = game_symbols(:jack)

    assert_difference -> { @game.symbols.count }, -1 do
      delete game_symbol_url(@game, unused)
    end

    assert_redirected_to game_url(@game)
  end

  test "refuses to remove a symbol in use, and says what is using it" do
    in_use = game_symbols(:ten)

    assert_no_difference -> { @game.symbols.count } do
      delete game_symbol_url(@game, in_use)
    end

    assert_redirected_to game_url(@game)
    follow_redirect!
    assert_select "#alert", /paytable/i
  end

  test "symbols cannot be added to or removed from another person's game" do
    someone_elses = games(:other_game)

    post game_symbols_url(someone_elses), params: { game_symbol: { code: "W" } }
    assert_response :not_found

    delete game_symbol_url(someone_elses, game_symbols(:foreign_ace))
    assert_response :not_found
  end

  test "a symbol can be added as wild" do
    post game_symbols_url(@game), params: { game_symbol: { code: "W", name: "Wild" } }

    assert_predicate @game.symbols.find_by(code: "W"), :wild?
  end

  test "an existing symbol can be marked wild and unmarked" do
    unused = game_symbols(:jack)

    patch game_symbol_url(@game, unused), params: { game_symbol: { wild: "1" } }
    assert_redirected_to game_url(@game)
    assert_predicate unused.reload, :wild?

    patch game_symbol_url(@game, unused), params: { game_symbol: { wild: "0" } }
    assert_not_predicate unused.reload, :wild?
  end

  test "marking a symbol that still pays is refused with the reason" do
    paying = game_symbols(:ten)

    patch game_symbol_url(@game, paying), params: { game_symbol: { wild: "1" } }

    assert_not_predicate paying.reload, :wild?
    follow_redirect!
    assert_select "#alert", /still pays/i
  end

  test "no marking option is offered once the game has a wild" do
    get game_url(@game)
    assert_select "button", text: "Mark wild"

    game_symbols(:jack).update!(wild: true)

    get game_url(@game)
    # Offering it would produce a button whose only outcome is a refusal.
    assert_select "button", { text: "Mark wild", count: 0 }
    assert_select "button", text: "Not wild"
  end

  test "a symbol named wild is not offered an unmark, because its name decides it" do
    @game.symbols.create!(code: "W", name: "Wild", position: 9)

    get game_url(@game)

    assert_select "button", { text: "Not wild", count: 0 }
    assert_select "button", { text: "Mark wild", count: 0 }
  end

  test "the add form drops the wild checkbox once one exists" do
    get game_url(@game)
    assert_select "input[name=?]", "game_symbol[wild]"

    game_symbols(:jack).update!(wild: true)

    get game_url(@game)
    assert_select "form input[type=checkbox][name=?]", "game_symbol[wild]", false
    assert_select "body", /is this game's wild/
  end

  test "what a wild does not substitute for can be set and cleared" do
    wild = game_symbols(:jack)
    wild.update!(wild: true)

    patch game_symbol_url(@game, wild), params: { game_symbol: { excluded_symbol_ids: [ game_symbols(:ace).id ] } }
    assert_equal [ game_symbols(:ace) ], wild.reload.excluded_symbols.to_a

    patch game_symbol_url(@game, wild), params: { game_symbol: { excluded_symbol_ids: [ "" ] } }
    assert_empty wild.reload.excluded_symbols
  end

  test "the substitution form appears only once a wild exists" do
    get game_url(@game)
    assert_select "body", { text: /does not substitute for/, count: 0 }

    game_symbols(:jack).update!(wild: true)

    get game_url(@game)
    assert_select "input[name=?]", "game_symbol[excluded_symbol_ids][]"
  end

  test "another person's symbol cannot be marked" do
    patch game_symbol_url(games(:other_game), game_symbols(:foreign_ace)), params: { game_symbol: { wild: "1" } }

    assert_response :not_found
  end

  test "the paytable shows the wild as substituting rather than paying" do
    game_symbols(:jack).update!(wild: true)

    get game_variation_url(@game, variations(:ninety_six))

    assert_select "[data-paytable] [data-wild-row]", /substitut/i
    assert_select "[data-paytable] input[name=?]", "payouts[#{game_symbols(:jack).id}][3]", false,
      "a wild has nowhere to enter a payout"
  end

  test "signing in is required" do
    sign_out

    post game_symbols_url(@game), params: { game_symbol: { code: "W" } }
    assert_redirected_to new_session_path
  end
end
