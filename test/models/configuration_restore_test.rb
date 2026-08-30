require "test_helper"

class ConfigurationRestoreTest < ActiveSupport::TestCase
  setup do
    @game = SampleGame::RedWhiteAndBlue.build_for(users(:one))
    @variation = @game.variations.first
    @checkpoint = RtpFigure.record(@variation, @variation.rtp)
  end

  def restore(figure = @checkpoint) = ConfigurationRestore.new(figure)

  test "it puts the reel strips and paytable back" do
    before = @variation.rtp.value
    @variation.reel_strips.first.update!(symbols: %w[ R7 R7 R7 ])
    @variation.paytable_entries.find_by(payout: 2400).update!(payout: 9)
    assert_not_equal before, @variation.reload.rtp.value

    restore.call

    assert_equal before, @variation.reload.rtp.value
  end

  test "it puts back a combination that was deleted" do
    @variation.paytable.find { |entry| entry.sequence == [ "Bars" ] * 3 }.destroy!
    assert_equal 14, @variation.reload.paytable.length

    restore.call

    assert_equal 15, @variation.reload.paytable.length
    assert @variation.paytable.any? { |entry| entry.sequence == [ "Bars" ] * 3 }
  end

  test "it removes a combination added after the checkpoint" do
    entry = @variation.paytable_entries.new(payout: 5)
    2.times { |i| entry.matchers.build(position: i + 1, game_symbol: @game.symbols.find_by(code: "R7")) }
    entry.save!

    restore.call

    assert_equal 15, @variation.reload.paytable.length
    assert_nil PaytableEntry.find_by(id: entry.id)
  end

  # The line that matters: these belong to the game and are shared with every other
  # variation, so putting them back here would rewrite what those compute.
  test "it leaves the game alone" do
    @game.paylines.create!(position: 2, rows: [ 0, 0, 0 ])
    @game.symbols.create!(code: "XX", name: "Extra", position: 90)
    group_count = @game.symbol_groups.count

    restore.call

    @game.reload
    assert_equal 2, @game.paylines.count, "a payline added since was removed by a restore"
    assert_not_nil @game.symbols.find_by(code: "XX"), "a symbol added since was removed by a restore"
    assert_equal group_count, @game.symbol_groups.count
  end

  test "it says what it will put back" do
    assert_equal [ "3 reel strips, 192 stops in total", "15 paytable combinations" ], restore.restoring
  end

  # A restore that quietly lands on a different number than the one clicked would be
  # worse than no restore at all.
  test "it says the figure will differ when the game has moved since" do
    @game.paylines.create!(position: 2, rows: [ 0, 0, 0 ])

    assert_predicate restore, :figure_will_differ?
    assert_equal [ "Paylines: 1 → 2" ], restore.leaving_alone.map(&:to_s)
  end

  test "an untouched game means the figure lands where it did" do
    @variation.reel_strips.first.update!(symbols: %w[ R7 R7 R7 ])

    assert_not_predicate restore, :figure_will_differ?
    assert_empty restore.leaving_alone
  end

  # Half a restore is worse than none: a paytable naming something that no longer
  # exists is not the configuration anybody is asking for.
  test "a snapshot naming a deleted symbol is refused rather than applied in part" do
    # A symbol in use cannot be deleted, so clearing what uses it comes first.
    @variation.paytable_entries.destroy_all
    @variation.reel_strips.destroy_all
    @game.symbols.find_by(code: "R7").destroy!

    attempt = restore
    assert_not_predicate attempt, :possible?
    assert_match(/symbol R7 no longer exist/, attempt.refusals.to_sentence)
    assert_raises(ArgumentError) { attempt.call }
    assert_equal 0, @variation.reload.paytable.length, "nothing was written"
  end

  test "a snapshot naming a deleted group is refused" do
    @game.symbol_groups.find_by(name: "Bars").destroy!

    attempt = restore
    assert_not_predicate attempt, :possible?
    assert_match(/group Bars no longer exist/, attempt.refusals.to_sentence)
  end

  test "a figure recorded before configurations were kept cannot be restored" do
    old = RtpFigure.create!(variation: @variation, numerator: 1, denominator: 2,
                            computed_by: "exact", fingerprint: "x", inputs: nil)

    assert_not_predicate restore(old), :possible?
    assert_match(/before configurations were kept/, restore(old).refusals.to_sentence)
  end

  # Restoring appends: the configuration being left behind stays in the history, so
  # going back is not the same as throwing away.
  test "what was there before a restore is still restorable afterwards" do
    @variation.reel_strips.first.update!(symbols: %w[ R7 R7 R7 ])
    detour = RtpFigure.record(@variation.reload, @variation.rtp)
    detoured_value = detour.value

    restore.call
    assert_equal @checkpoint.value, @variation.reload.rtp.value

    ConfigurationRestore.new(detour).call
    assert_equal detoured_value, @variation.reload.rtp.value
  end
end
