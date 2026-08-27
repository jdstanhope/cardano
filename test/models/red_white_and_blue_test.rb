require "test_helper"

# Red White & Blue, the version published as returning 86.58% for one coin.
#
# This is the only check that exercises the evaluation *rules* against something
# nobody here produced. Brute force shares WinMechanic with the calculation, so a wrong
# rule is wrong identically in both routes and they still agree; the other published
# figure pays one combination and proves only the arithmetic.
#
# Fifteen overlapping combinations, ordered sequences, groups, a symbol in several
# groups at once, and a blank that pays. If best-interpretation-once were wrong, the
# total would be wrong rather than an error.
#
# The definition lives in SampleGame::RedWhiteAndBlue rather than here, because it is
# also what somebody copies into their account. The sample being the same data this
# verifies means the example handed to a newcomer is one the calculation is proven
# against, rather than one that merely looks plausible.
#
# Source: https://wizardofodds.com/games/slots/appendix/6/
class RedWhiteAndBlueTest < ActiveSupport::TestCase
  SAMPLE = SampleGame::RedWhiteAndBlue
  PUBLISHED_RETURN = SAMPLE::PUBLISHED_RETURN
  COMBINATIONS = SAMPLE::COMBINATIONS

  setup do
    @game = SAMPLE.build_for(users(:one))
    @variation = @game.variations.first
  end

  test "the strips match the published machine" do
    assert_equal [ 64, 64, 64 ], @variation.reel_strips.sort_by(&:position).map { |strip| strip.symbols.length }
    assert_equal COMBINATIONS, @variation.reel_strips.map { |strip| strip.symbols.length }.reduce(:*)
  end

  test "a red seven is both a seven and a red" do
    assert_equal %w[ Reds Sevens ], @game.symbols.find_by(code: "R7").symbol_groups.map(&:name).sort
  end

  test "every published combination came across" do
    assert_equal SAMPLE::DEFINITION.fetch(:pays).length, @variation.paytable_entries.count
    assert_equal SAMPLE::DEFINITION.fetch(:pays).map(&:first).sort, @variation.paytable_entries.map(&:payout).sort
  end

  test "the return matches the published figure" do
    computed = @variation.rtp

    assert_predicate computed, :exact?
    assert_in_delta PUBLISHED_RETURN, computed.value.to_f, 0.00005,
      "computed #{computed.to_percentage(4)} against a published 86.58%"
  end

  test "the expectation agrees with walking all 262,144 outcomes" do
    strips = @variation.reel_strips.sort_by(&:position)
    mechanic = WinMechanic.for(@game)
    entries = @variation.paytable
    by_code = @game.symbols.index_by(&:code)

    payout = 0
    ranges = strips.map { |strip| (0...strip.symbols.length).to_a }
    ranges[0].product(*ranges[1..]) do |stops|
      columns = strips.each_with_index.map { |strip, reel| [ by_code[strip.symbols[stops[reel]]] ] }
      payout += mechanic.wins(ReelWindow.new(@game, columns), entries).sum(&:payout)
    end

    assert_equal Rational(payout, COMBINATIONS), @variation.rtp.value
  end
end
