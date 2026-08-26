require "test_helper"

class SymbolGroupingTest < ActiveSupport::TestCase
  setup do
    @game = games(:five_by_three)
    @ace = game_symbols(:ace)
    @king = game_symbols(:king)
    @sevens = @game.symbol_groups.create!(name: "Sevens", position: 1)
  end

  test "a group holds symbols" do
    @sevens.game_symbols << @ace

    assert_equal [ @ace ], @sevens.reload.game_symbols.to_a
    assert_includes @ace.reload.symbol_groups, @sevens
  end

  test "a symbol belongs to several groups at once" do
    reds = @game.symbol_groups.create!(name: "Reds", position: 2)
    @sevens.game_symbols << @ace
    reds.game_symbols << @ace

    assert_equal [ "Reds", "Sevens" ], @ace.reload.symbol_groups.map(&:name).sort,
      "a red seven is both a seven and a red, and both get paid for separately"
  end

  test "group names are unique within a game but not across games" do
    assert_not @game.symbol_groups.new(name: "Sevens", position: 9).valid?
    assert games(:other_game).symbol_groups.new(name: "Sevens", position: 1).valid?
  end

  test "a group needs a name" do
    assert_not @game.symbol_groups.new(position: 9).valid?
  end

  test "a group cannot hold a symbol from another game" do
    membership = SymbolGroupMembership.new(symbol_group: @sevens, game_symbol: game_symbols(:foreign_ace))

    assert_not membership.valid?
    assert_match(/game/i, membership.errors[:game_symbol].to_sentence)
  end

  test "a symbol is not added to the same group twice" do
    @sevens.game_symbols << @ace

    assert_not SymbolGroupMembership.new(symbol_group: @sevens, game_symbol: @ace).valid?
  end

  test "removing a group leaves its symbols alone" do
    @sevens.game_symbols << @ace
    @sevens.destroy!

    assert_predicate @ace.reload, :persisted?
    assert_empty @ace.symbol_groups
  end

  test "removing a symbol removes it from its groups, and is not blocked by them" do
    spare = @game.symbols.create!(code: "SP", position: 30)
    @sevens.game_symbols << spare

    assert spare.destroy, "belonging to a group should not stop a symbol being removed"
    assert_empty @sevens.reload.game_symbols
  end

  test "destroying a game takes its groups with it" do
    @sevens.game_symbols << @ace

    assert_nothing_raised { @game.destroy! }

    assert_empty SymbolGroup.where(game_id: @game.id)
    assert_empty SymbolGroupMembership.where(symbol_group_id: @sevens.id)
  end

  test "a group knows whether a symbol is in it" do
    @sevens.game_symbols << @ace

    assert @sevens.includes_symbol?(@ace)
    assert_not @sevens.includes_symbol?(@king)
  end
end
