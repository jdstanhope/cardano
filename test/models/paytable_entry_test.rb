require "test_helper"

class PaytableEntryTest < ActiveSupport::TestCase
  setup do
    @variation = variations(:ninety_six)
    @game = @variation.game
    @ace = game_symbols(:ace)
    @king = game_symbols(:king)
  end

  def build(payout: 5, things: [ @king, @king, @king ])
    @variation.paytable_entries.new(payout: payout).tap do |entry|
      things.each_with_index do |thing, index|
        key = thing.is_a?(SymbolGroup) ? :symbol_group : :game_symbol
        entry.matchers.build(position: index + 1, key => thing)
      end
    end
  end

  test "a combination is a sequence of matchers" do
    entry = build(things: [ @ace, @king, @ace ])

    assert entry.valid?, entry.errors.full_messages.to_sentence
    assert_equal 3, entry.length
    assert_equal %w[ A K A ], entry.sequence
  end

  test "nothing pays for a single symbol" do
    assert_not build(things: [ @king ]).valid?
  end

  test "two of a kind is allowed, since some games do pay from two" do
    assert build(things: [ @king, @king ]).valid?
  end

  test "a combination cannot be longer than the reels" do
    assert build(things: [ @king ] * @game.reel_count).valid?
    assert_not build(things: [ @king ] * (@game.reel_count + 1)).valid?
  end

  test "a payout is a positive whole number" do
    assert_not build(payout: 0).valid?
    assert_not build(payout: -5).valid?
  end

  test "a matcher names one symbol or one group, not both" do
    bars = @game.symbol_groups.create!(name: "Bars", position: 1)
    matcher = PaytableMatcher.new(paytable_entry: build, position: 1, game_symbol: @ace, symbol_group: bars)

    assert_not matcher.valid?
  end

  test "a matcher naming neither is rejected" do
    assert_not PaytableMatcher.new(paytable_entry: build, position: 1).valid?
  end

  test "a matcher cannot name a symbol from another game" do
    entry = build
    entry.matchers.build(position: 9, game_symbol: game_symbols(:foreign_ace))

    assert_not entry.valid?
  end

  test "a combination matches a line whose opening symbols satisfy it" do
    entry = build(things: [ @ace, @ace ])
    entry.save!

    assert entry.matches?([ @ace, @ace, @king, @king, @king ])
    assert entry.matches?([ @ace, @ace, @ace, @ace, @ace ]), "a longer line still opens with two aces"
    assert_not entry.matches?([ @king, @ace, @ace, @king, @king ]), "it must start on the leftmost reel"
    assert_not entry.matches?([ @ace ]), "a line shorter than the combination cannot satisfy it"
  end

  test "a group matcher matches any member" do
    bars = @game.symbol_groups.create!(name: "Bars", position: 1)
    bars.game_symbols << [ @ace, @king ]
    entry = build(things: [ bars, bars ])
    entry.save!

    assert entry.matches?([ @ace, @king, @king ])
    assert entry.matches?([ @king, @ace, @king ])
    assert_not entry.matches?([ game_symbols(:queen), @ace, @king ])
  end

  test "destroying a combination takes its matchers" do
    entry = build
    entry.save!

    assert_difference -> { PaytableMatcher.count }, -3 do
      entry.destroy
    end
  end
end
