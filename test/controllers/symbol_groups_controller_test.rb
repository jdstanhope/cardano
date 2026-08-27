require "test_helper"

class SymbolGroupsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @game = games(:five_by_three)
    sign_in_as @game.user
  end

  test "adds a group" do
    assert_difference -> { @game.symbol_groups.count }, 1 do
      post game_symbol_groups_url(@game), params: { symbol_group: { name: "Sevens" } }
    end

    assert_redirected_to game_url(@game)
    assert_equal "Sevens", @game.symbol_groups.last.name
  end

  test "a duplicate name is reported rather than silently ignored" do
    @game.symbol_groups.create!(name: "Sevens", position: 1)

    assert_no_difference -> { @game.symbol_groups.count } do
      post game_symbol_groups_url(@game), params: { symbol_group: { name: "Sevens" } }
    end

    follow_redirect!
    assert_select "#alert"
  end

  test "membership can be set and cleared" do
    group = @game.symbol_groups.create!(name: "Sevens", position: 1)
    ace = game_symbols(:ace)

    patch game_symbol_group_url(@game, group), params: { symbol_group: { game_symbol_ids: [ ace.id ] } }
    assert_equal [ ace ], group.reload.game_symbols.to_a

    patch game_symbol_group_url(@game, group), params: { symbol_group: { game_symbol_ids: [ "" ] } }
    assert_empty group.reload.game_symbols
  end

  test "a symbol can be put in several groups" do
    sevens = @game.symbol_groups.create!(name: "Sevens", position: 1)
    reds = @game.symbol_groups.create!(name: "Reds", position: 2)
    ace = game_symbols(:ace)

    patch game_symbol_group_url(@game, sevens), params: { symbol_group: { game_symbol_ids: [ ace.id ] } }
    patch game_symbol_group_url(@game, reds), params: { symbol_group: { game_symbol_ids: [ ace.id ] } }

    assert_equal 2, ace.reload.symbol_groups.count
  end

  test "removing a group leaves the symbols" do
    group = @game.symbol_groups.create!(name: "Sevens", position: 1)
    group.game_symbols << game_symbols(:ace)
    before = @game.symbols.count

    delete game_symbol_group_url(@game, group)

    assert_equal before, @game.symbols.reload.count
  end

  test "the game page offers the groups section" do
    get game_url(@game)

    assert_response :success
    assert_select "[data-symbol-groups]", /group/i
  end

  test "another person's game cannot have groups added or changed" do
    post game_symbol_groups_url(games(:other_game)), params: { symbol_group: { name: "Sevens" } }
    assert_response :not_found
  end

  test "signing in is required" do
    sign_out

    post game_symbol_groups_url(@game), params: { symbol_group: { name: "Sevens" } }
    assert_redirected_to new_session_path
  end
end
