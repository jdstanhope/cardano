require "test_helper"

class VariationBranchTest < ActiveSupport::TestCase
  setup do
    @game = SampleGame::RedWhiteAndBlue.build_for(users(:one))
    @variation = @game.variations.first
  end

  test "a branch from a variation carries what it holds now" do
    branch = VariationBranch.from_variation(@variation).call

    assert_equal 2, branch.number
    assert_equal @variation.rtp.value, branch.rtp.value
    assert_equal 15, branch.paytable.length
    assert_equal [ 64, 64, 64 ], branch.reel_strips.map { |strip| strip.symbols.length }
  end

  # The whole point: trying something without risking what works.
  test "the variation branched from is untouched" do
    before = @variation.rtp.value
    branch = VariationBranch.from_variation(@variation).call

    branch.paytable_entries.find_by(payout: 2400).update!(payout: 9)

    assert_equal before, @variation.reload.rtp.value
    assert_equal 2400, @variation.paytable.find { |entry| entry.sequence == %w[ R7 W7 B7 ] }.payout
  end

  test "a branch from a checkpoint carries that configuration, not the current one" do
    checkpoint = RtpFigure.record(@variation, @variation.rtp)
    @variation.paytable_entries.find_by(payout: 2400).update!(payout: 9)
    assert_not_equal checkpoint.value, @variation.reload.rtp.value

    branch = VariationBranch.from_figure(checkpoint).call

    assert_equal checkpoint.value, branch.rtp.value
  end

  test "branching a checkpoint records nothing against the variation it came from" do
    checkpoint = RtpFigure.record(@variation, @variation.rtp)

    assert_no_difference -> { @variation.rtp_figures.count } do
      VariationBranch.from_figure(checkpoint).call
    end
  end

  # Symbols, groups, paylines, the window and the mechanic belong to the game, and the
  # new variation is in the same game, so it already has them.
  test "nothing belonging to the game is copied" do
    symbols = @game.symbols.count
    groups = @game.symbol_groups.count
    paylines = @game.paylines.count

    VariationBranch.from_variation(@variation).call

    @game.reload
    assert_equal symbols, @game.symbols.count
    assert_equal groups, @game.symbol_groups.count
    assert_equal paylines, @game.paylines.count
  end

  test "it carries the target band across" do
    branch = VariationBranch.from_variation(@variation).call

    assert_equal @variation.target_rtp_min, branch.target_rtp_min
    assert_equal @variation.target_rtp_max, branch.target_rtp_max
  end

  test "it says what the branch will hold before making one" do
    assert_equal [ "3 reel strips, 192 stops in total", "15 paytable combinations" ],
                 VariationBranch.from_variation(@variation).carrying
  end

  test "a game with no free number refuses, with the reason" do
    (2..99).each { |number| @game.variations.create!(number: number) }

    attempt = VariationBranch.from_variation(@variation)

    assert_not_predicate attempt, :possible?
    assert_match(/already has all 99 variations/, attempt.refusals.to_sentence)
    assert_raises(ArgumentError) { attempt.call }
  end

  test "a checkpoint naming something deleted cannot be branched either" do
    checkpoint = RtpFigure.record(@variation, @variation.rtp)
    @game.symbol_groups.find_by(name: "Bars").destroy!

    attempt = VariationBranch.from_figure(checkpoint)

    assert_not_predicate attempt, :possible?
    assert_match(/group Bars no longer exist/, attempt.refusals.to_sentence)
  end

  test "a failure part way leaves no variation behind" do
    checkpoint = RtpFigure.record(@variation, @variation.rtp)
    count = @game.variations.count

    PaytableEntry.define_singleton_method(:new) { |*| raise "no further" }

    begin
      assert_raises(RuntimeError) { VariationBranch.from_figure(checkpoint).call }
    ensure
      PaytableEntry.singleton_class.remove_method(:new)
    end

    assert_equal count, @game.variations.reload.count
  end

  test "branching an empty variation makes an empty one rather than failing" do
    empty = @game.variations.create!(number: 2)

    branch = VariationBranch.from_variation(empty).call

    assert_equal 3, branch.number
    assert_empty branch.reel_strips
    assert_empty branch.paytable_entries
  end
end
