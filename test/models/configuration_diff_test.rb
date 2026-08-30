require "test_helper"

# The diff has to report everything the figure depends on. A change it misses reads as
# nothing having happened while the figure moves — wrong rather than absent, which is
# the failure worth guarding against, so there is a case per input.
class ConfigurationDiffTest < ActiveSupport::TestCase
  setup do
    @game = SampleGame::RedWhiteAndBlue.build_for(users(:one))
    @variation = @game.variations.first
    @before = RtpFingerprint.inputs_for(@variation)
  end

  def diff_after
    @variation.reload
    ConfigurationDiff.new(@before, RtpFingerprint.inputs_for(@variation))
  end

  test "an unchanged description has nothing to report" do
    assert_predicate diff_after, :none?
  end

  # Inserting one stop shifts every stop below it. Reported position by position that
  # is fifty changes; as a tally it is the one change that was made.
  test "a changed reel reports the tally, not every shifted position" do
    strip = @variation.reel_strips.first
    strip.update!(symbols: strip.symbols.dup.insert(3, "R7"))

    # The tally is the whole story: the length is its sum, so repeating it adds nothing.
    assert_equal [ "Reel 1: R7 1 → 2" ], diff_after.to_a
  end

  test "a reel reordered without changing its counts says so" do
    strip = @variation.reel_strips.first
    strip.update!(symbols: strip.symbols.reverse)

    assert_equal [ "Reel 1: order changed" ], diff_after.to_a
  end

  test "a repriced combination reads as one change, not a removal and an addition" do
    @variation.paytable_entries.find_by(payout: 2400).update!(payout: 4800)

    assert_equal [ "R7 W7 B7: 2400 → 4800" ], diff_after.to_a
  end

  test "a removed combination is reported" do
    @variation.paytable.find { |entry| entry.sequence == [ "Bars" ] * 3 }.destroy!

    assert_equal [ "any Bars any Bars any Bars: no longer pays" ], diff_after.to_a
  end

  test "an added combination is reported with what it pays" do
    entry = @variation.paytable_entries.new(payout: 7)
    %w[ R7 W7 ].each_with_index { |code, index| entry.matchers.build(position: index + 1, game_symbol: @game.symbols.find_by(code: code)) }
    entry.save!

    assert_equal [ "R7 W7: now pays 7" ], diff_after.to_a
  end

  test "a group position reads as the group it accepts" do
    @variation.paytable.find { |entry| entry.sequence == [ "Sevens" ] * 3 }.update!(payout: 90)

    assert_equal [ "any Sevens any Sevens any Sevens: 80 → 90" ], diff_after.to_a
  end

  test "a changed group membership is reported" do
    @game.symbol_groups.find_by(name: "Sevens").game_symbols << @game.symbols.find_by(code: "--")

    assert_equal [ "Group Sevens: B7 R7 W7 → -- B7 R7 W7" ], diff_after.to_a
  end

  test "a new payline is reported" do
    @game.paylines.create!(position: 2, rows: [ 0, 0, 0 ])

    assert_equal [ "Paylines: 1 → 2" ], diff_after.to_a
  end

  test "a symbol becoming wild is reported" do
    symbol = @game.symbols.create!(code: "XX", name: "Extra", position: 90)
    @before = RtpFingerprint.inputs_for(@variation.reload)

    symbol.update!(wild: true)

    assert_equal [ "Symbol XX: is now wild" ], diff_after.to_a
  end

  test "a wild's substitutions changing is reported" do
    wild = @game.symbols.create!(code: "WW", name: "Wild", position: 91)
    @before = RtpFingerprint.inputs_for(@variation.reload)

    wild.wild_exclusions.create!(excluded: @game.symbols.find_by(code: "R7"))

    assert_equal [ "Symbol WW: substitutions changed" ], diff_after.to_a
  end

  test "the reel window is reported" do
    @game.update!(row_count: 3)

    assert_equal [ "Reel window: 3×1 → 3×3" ], diff_after.to_a
  end

  # A change to the game is shared with every other variation, so it was not
  # necessarily made here and cannot be put back from here.
  test "changes are split by what owns them" do
    strip = @variation.reel_strips.first
    strip.update!(symbols: strip.symbols.reverse)
    @game.paylines.create!(position: 2, rows: [ 0, 0, 0 ])

    diff = diff_after

    assert_equal [ "Reel 1: order changed" ], diff.of_the_variation.map(&:to_s)
    assert_equal [ "Paylines: 1 → 2" ], diff.of_the_game.map(&:to_s)
  end

  test "several changes at once are all reported" do
    @variation.reel_strips.first.then { |strip| strip.update!(symbols: strip.symbols.reverse) }
    @variation.paytable_entries.find_by(payout: 2400).update!(payout: 4800)

    assert_equal 2, diff_after.changes.length
  end

  # Figures recorded before snapshots existed have nothing to compare, and inventing a
  # comparison for them would be claiming knowledge the record does not hold.
  test "a figure with no stored description reports nothing rather than guessing" do
    later = RtpFigure.record(@variation, @variation.rtp)
    earlier = RtpFigure.create!(variation: @variation, numerator: 1, denominator: 2,
                                computed_by: "exact", fingerprint: "old", inputs: nil)

    assert_nil later.changes_from(earlier)
    assert_nil later.changes_from(nil)
  end
end
