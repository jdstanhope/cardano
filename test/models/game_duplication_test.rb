require "test_helper"

class GameDuplicationTest < ActiveSupport::TestCase
  setup do
    @source = SampleGame::RedWhiteAndBlue.build_for(users(:one))
  end

  # The whole point, in one number. A duplicate returning the same figure means every
  # symbol, group, membership, strip, payline and paytable combination came across and
  # is wired to the copy's own records — no assertion about counts covers that.
  test "a duplicate computes the same return as its original" do
    copy = GameDuplication.call(@source, owner: users(:one))

    assert_equal @source.variations.first.rtp.value, copy.variations.first.rtp.value
  end

  test "it copies the whole game" do
    copy = GameDuplication.call(@source, owner: users(:one))
    variation = copy.variations.first

    assert_equal @source.symbols.count, copy.symbols.count
    assert_equal @source.symbol_groups.count, copy.symbol_groups.count
    assert_equal @source.paylines.count, copy.paylines.count
    assert_equal @source.variations.count, copy.variations.count
    assert_equal @source.variations.first.reel_strips.count, variation.reel_strips.count
    assert_equal @source.variations.first.paytable_entries.count, variation.paytable_entries.count
    assert_equal 3, copy.reel_count
    assert_equal 1, copy.row_count
  end

  test "group membership survives, including a symbol in several groups" do
    copy = GameDuplication.call(@source, owner: users(:one))

    assert_equal %w[ Reds Sevens ], copy.symbols.find_by(code: "R7").symbol_groups.map(&:name).sort
  end

  # A reference left pointing at the original would not raise. The copy would look
  # right and quietly share a paytable with the game it was made from, so that editing
  # one changed the other.
  test "nothing in the copy points at the original's records" do
    copy = GameDuplication.call(@source, owner: users(:one))
    original_symbols = @source.symbols.pluck(:id)
    original_groups = @source.symbol_groups.pluck(:id)

    matchers = PaytableMatcher.where(paytable_entry: copy.variations.first.paytable_entries)

    assert_empty matchers.where(game_symbol_id: original_symbols)
    assert_empty matchers.where(symbol_group_id: original_groups)
    assert_empty SymbolGroupMembership.where(symbol_group: copy.symbol_groups, game_symbol_id: original_symbols)
    assert_operator matchers.count, :>, 0, "the copy has a paytable to check in the first place"
  end

  test "editing the copy leaves the original alone" do
    copy = GameDuplication.call(@source, owner: users(:one))
    before = @source.variations.first.rtp.value

    copy.variations.first.paytable_entries.first.update!(payout: 9999)

    assert_equal before, @source.reload.variations.first.rtp.value
    assert_not_equal before, copy.reload.variations.first.rtp.value
  end

  test "a wild's substitution rules come across against the copy's own symbols" do
    wild = @source.symbols.create!(code: "WW", name: "Wild", position: 99)
    scatter = @source.symbols.find_by(code: "R7")
    wild.wild_exclusions.create!(excluded: scatter)

    copy = GameDuplication.call(@source.reload, owner: users(:one))
    copied_wild = copy.symbols.find_by(code: "WW")

    assert_predicate copied_wild, :wild?
    assert_equal [ "R7" ], copied_wild.excluded_symbols.map(&:code)
    assert_equal copy.symbols.pluck(:id).sort, (copy.symbols.pluck(:id) | copied_wild.excluded_symbols.map(&:id)).sort
  end

  test "it names the copy after the original, and numbers a second one" do
    first = GameDuplication.call(@source, owner: users(:one))
    second = GameDuplication.call(@source, owner: users(:one))

    assert_equal "Red White & Blue (copy)", first.name
    assert_equal "Red White & Blue (copy) 2", second.name
  end

  test "it takes a name when given one" do
    copy = GameDuplication.call(@source, owner: users(:one), name: "Tuned for 94%")

    assert_equal "Tuned for 94%", copy.name
  end

  test "the copy belongs to whoever asked for it" do
    copy = GameDuplication.call(@source, owner: users(:two))

    assert_equal users(:two), copy.user
    assert_equal users(:one), @source.reload.user
  end

  # Half a game is worse than none: it would compute a figure from a paytable that lost
  # combinations on the way across, and read as a complete game while doing it.
  test "a failure part way leaves no game behind" do
    count = users(:one).games.count

    PaytableEntry.define_singleton_method(:new) { |*| raise "no further" }

    begin
      assert_raises(RuntimeError) { GameDuplication.call(@source, owner: users(:one)) }
    ensure
      PaytableEntry.singleton_class.remove_method(:new)
    end

    assert_equal count, users(:one).games.count
    assert_equal 0, SymbolGroup.where.not(game: @source).count
  end
end
