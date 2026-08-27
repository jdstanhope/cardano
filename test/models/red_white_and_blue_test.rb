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
# Source: https://wizardofodds.com/games/slots/appendix/6/
class RedWhiteAndBlueTest < ActiveSupport::TestCase
  PUBLISHED_RETURN = 0.8658
  COMBINATIONS = 262_144

  STRIPS = {
    "R7" => [ 1, 3, 1 ],
    "W7" => [ 6, 1, 7 ],
    "B7" => [ 6, 7, 1 ],
    "3B" => [ 6, 7, 5 ],
    "2B" => [ 7, 6, 9 ],
    "1B" => [ 6, 8, 9 ],
    "--" => [ 32, 32, 32 ]
  }.freeze

  # The source does not say which symbols are red, white or blue. The classic design
  # colours the bars: one bar red, two bar white, three bar blue. That makes
  # "1 bar, 2 bar, 3 bar" a specific case of "any red, any white, any blue", which is
  # why both are paid and the specific pays more.
  GROUPS = {
    "Sevens" => %w[ R7 W7 B7 ],
    "Bars" => %w[ 1B 2B 3B ],
    "Reds" => %w[ R7 1B ],
    "Whites" => %w[ W7 2B ],
    "Blues" => %w[ B7 3B ]
  }.freeze

  # Each combination as it is published, one coin.
  PAYS = [
    [ 2400, %w[ R7 W7 B7 ] ],
    [ 1199, %w[ R7 R7 R7 ] ],
    [  200, %w[ W7 W7 W7 ] ],
    [  150, %w[ B7 B7 B7 ] ],
    [   80, %w[ Sevens Sevens Sevens ] ],
    [   50, %w[ 1B 2B 3B ] ],
    [   40, %w[ 3B 3B 3B ] ],
    [   25, %w[ 2B 2B 2B ] ],
    [   20, %w[ Reds Whites Blues ] ],
    [   10, %w[ 1B 1B 1B ] ],
    [    5, %w[ Bars Bars Bars ] ],
    [    2, %w[ Reds Reds Reds ] ],
    [    2, %w[ Whites Whites Whites ] ],
    [    2, %w[ Blues Blues Blues ] ],
    [    1, %w[ -- -- -- ] ]
  ].freeze

  setup do
    @game = users(:one).games.create!(name: "Red White & Blue", reel_count: 3, row_count: 1)

    @symbols = STRIPS.keys.each_with_index.to_h do |code, index|
      [ code, @game.symbols.create!(code: code, position: index + 1) ]
    end

    @groups = GROUPS.each_with_index.to_h do |(name, members), index|
      group = @game.symbol_groups.create!(name: name, position: index + 1)
      group.game_symbols << members.map { |code| @symbols.fetch(code) }
      [ name, group ]
    end

    @game.paylines.create!(position: 1, rows: [ 0, 0, 0 ])

    @variation = @game.variations.first
    3.times do |reel|
      codes = STRIPS.flat_map { |code, counts| Array.new(counts[reel], code) }
      @variation.reel_strips.create!(position: reel + 1, symbols: codes)
    end

    PAYS.each do |payout, sequence|
      entry = @variation.paytable_entries.new(payout: payout)
      sequence.each_with_index do |name, index|
        thing = @symbols[name] || @groups.fetch(name)
        key = thing.is_a?(SymbolGroup) ? :symbol_group : :game_symbol
        entry.matchers.build(position: index + 1, key => thing)
      end
      entry.save!
    end

    @variation.reload
  end

  test "the strips match the published machine" do
    assert_equal [ 64, 64, 64 ], @variation.reel_strips.sort_by(&:position).map { |strip| strip.symbols.length }
    assert_equal COMBINATIONS, @variation.reel_strips.map { |strip| strip.symbols.length }.reduce(:*)
  end

  test "a red seven is both a seven and a red" do
    assert_equal %w[ Reds Sevens ], @symbols.fetch("R7").symbol_groups.map(&:name).sort
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
