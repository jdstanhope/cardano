require "test_helper"

class WildSubstitutionTest < ActiveSupport::TestCase
  setup do
    @game = games(:five_by_three)
    @wild = game_symbols(:jack)
    @wild.update!(wild: true)
    @ace = game_symbols(:ace)
    @king = game_symbols(:king)
  end

  test "by default a wild substitutes for every other symbol" do
    @game.symbols.where.not(id: @wild.id).each do |symbol|
      assert @wild.substitutes_for?(symbol), "should substitute for #{symbol.code} without being told to"
    end
  end

  test "a wild does not substitute for itself" do
    assert_not @wild.substitutes_for?(@wild)
  end

  test "an excluded symbol is not substituted for" do
    @wild.excluded_symbols << @ace

    assert_not @wild.substitutes_for?(@ace)
    assert @wild.substitutes_for?(@king), "excluding one symbol should not affect the others"
  end

  test "a symbol added after the exclusions are set is substitutable" do
    @wild.excluded_symbols << @ace

    added = @game.symbols.create!(code: "N", name: "New", position: 20)

    assert @wild.substitutes_for?(added),
      "a deny list has to fail toward substituting, or a later symbol is silently excluded"
  end

  test "only a wild can carry exclusions" do
    exclusion = WildExclusion.new(wild: @ace, excluded: @king)

    assert_not exclusion.valid?
    assert_match(/wild/i, exclusion.errors[:wild].to_sentence)
  end

  test "a wild cannot exclude itself" do
    assert_not WildExclusion.new(wild: @wild, excluded: @wild).valid?
  end

  test "a wild cannot exclude a symbol from another game" do
    assert_not WildExclusion.new(wild: @wild, excluded: game_symbols(:foreign_ace)).valid?
  end

  test "the same symbol cannot be excluded twice" do
    @wild.excluded_symbols << @ace

    assert_not WildExclusion.new(wild: @wild, excluded: @ace).valid?
  end

  test "removing an excluded symbol removes the exclusion with it" do
    # A fresh symbol, because the fixture symbols are on reel strips and the removal
    # guard rightly refuses those. An exclusion should not itself block removal.
    spare = @game.symbols.create!(code: "SP", name: "Spare", position: 30)
    @wild.excluded_symbols << spare
    assert_equal 1, @wild.wild_exclusions.count

    assert spare.destroy, "an exclusion should not stop a symbol being removed"

    assert_equal 0, @wild.wild_exclusions.reload.count
  end

  test "unmarking a wild clears what it was configured not to substitute for" do
    @wild.excluded_symbols << @ace
    @wild.update!(wild: false)

    assert_empty @wild.wild_exclusions.reload,
      "a symbol that is not wild has nothing to substitute for, so the list is meaningless"
  end

  test "a non-wild symbol substitutes for nothing" do
    assert_not @ace.substitutes_for?(@king)
  end
end
