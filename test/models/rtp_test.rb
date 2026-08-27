require "test_helper"

class RtpTest < ActiveSupport::TestCase
  # Walks every stop combination and totals what it pays. A completely separate route
  # to the same number: no expectation, no factorising, just every outcome added up.
  # If the two disagree, one of them is wrong.
  def brute_force(variation)
    game = variation.game
    strips = variation.reel_strips.sort_by(&:position)
    mechanic = WinMechanic.for(game)
    entries = variation.paytable
    by_code = game.symbols.index_by(&:code)

    stop_counts = strips.map { |strip| strip.symbols.length }
    total = stop_counts.reduce(:*)
    payout = 0

    stop_counts.map { |count| (0...count).to_a }.then { |ranges| ranges[0].product(*ranges[1..]) }.each do |stops|
      columns = strips.each_with_index.map do |strip, reel|
        game.row_count.times.map { |offset| by_code[strip.symbols[(stops[reel] + offset) % strip.symbols.length]] }
      end

      payout += mechanic.wins(ReelWindow.new(game, columns), entries).sum(&:payout)
    end

    Rational(payout, total * mechanic.stake_units)
  end

  # A combination is a sequence of matchers, so N of a kind is one symbol repeated.
  def create_entry(variation, symbols, payout)
    entry = variation.paytable_entries.new(payout: payout)
    symbols.each_with_index { |symbol, index| entry.matchers.build(position: index + 1, game_symbol: symbol) }
    entry.save!
    entry
  end

  def build_game(user: users(:one), name:, **attributes)
    user.games.create!(name: name, reel_count: 3, row_count: 1, **attributes)
  end

  # --- a published figure -----------------------------------------------------

  # A three reel game with twenty symbols per reel and one winning combination paying
  # 7,500 has a documented theoretical return of 7500 / 8000 = 93.75%. Nobody here
  # chose that number, which is the point of using it.
  test "reproduces a published theoretical return" do
    game = build_game(name: "Published", reel_count: 3, row_count: 1)
    seven = game.symbols.create!(code: "7", position: 1)
    blank = game.symbols.create!(code: "-", position: 2)
    game.paylines.create!(position: 1, rows: [ 0, 0, 0 ])

    variation = game.variations.first
    3.times do |reel|
      variation.reel_strips.create!(position: reel + 1, symbols: [ "7" ] + Array.new(19, "-"))
    end
    create_entry(variation, [ seven, seven, seven ], 7500)

    result = variation.rtp

    assert_equal Rational(7500, 8000), result.value
    assert_equal "93.75%", result.to_percentage
    assert_predicate result, :exact?
    assert_equal blank, game.symbols.find_by(code: "-")
  end

  # --- agreement with brute force ---------------------------------------------

  test "a lines game agrees exactly with walking every outcome" do
    game = build_game(name: "Small lines", reel_count: 3, row_count: 3)
    a = game.symbols.create!(code: "A", position: 1)
    k = game.symbols.create!(code: "K", position: 2)
    game.paylines.create!(position: 1, rows: [ 0, 0, 0 ])
    game.paylines.create!(position: 2, rows: [ 1, 0, -1 ])

    variation = game.variations.first
    variation.reel_strips.create!(position: 1, symbols: %w[ A K K A ])
    variation.reel_strips.create!(position: 2, symbols: %w[ A A K K K ])
    variation.reel_strips.create!(position: 3, symbols: %w[ K A K ])
    create_entry(variation, [ a ] * 3, 10)
    create_entry(variation, [ k ] * 2, 3)

    assert_equal brute_force(variation.reload), variation.rtp.value
  end

  test "a ways game agrees exactly with walking every outcome" do
    game = build_game(name: "Small ways", reel_count: 3, row_count: 2, win_mechanic: "ways")
    a = game.symbols.create!(code: "A", position: 1)
    k = game.symbols.create!(code: "K", position: 2)

    variation = game.variations.first
    variation.reel_strips.create!(position: 1, symbols: %w[ A K K A ])
    variation.reel_strips.create!(position: 2, symbols: %w[ A A K K K ])
    variation.reel_strips.create!(position: 3, symbols: %w[ K A K ])
    create_entry(variation, [ a ] * 2, 5)
    create_entry(variation, [ k ] * 3, 8)

    assert_equal brute_force(variation.reload), variation.rtp.value
  end

  test "a wild is accounted for identically by both routes" do
    game = build_game(name: "Wild lines", reel_count: 3, row_count: 1)
    a = game.symbols.create!(code: "A", position: 1)
    game.symbols.create!(code: "K", position: 2)
    game.symbols.create!(code: "W", name: "Wild", position: 3)
    game.paylines.create!(position: 1, rows: [ 0, 0, 0 ])

    variation = game.variations.first
    variation.reel_strips.create!(position: 1, symbols: %w[ A K W ])
    variation.reel_strips.create!(position: 2, symbols: %w[ A K W K ])
    variation.reel_strips.create!(position: 3, symbols: %w[ A W K ])
    create_entry(variation, [ a ] * 3, 20)

    assert_operator variation.rtp.value, :>, 0, "the wild should be creating wins"
    assert_equal brute_force(variation.reload), variation.rtp.value
  end

  test "a wild told to leave a symbol alone is accounted for by both routes" do
    game = build_game(name: "Restricted wild", reel_count: 3, row_count: 1)
    a = game.symbols.create!(code: "A", position: 1)
    k = game.symbols.create!(code: "K", position: 2)
    wild = game.symbols.create!(code: "W", name: "Wild", position: 3)
    wild.excluded_symbols << k
    game.paylines.create!(position: 1, rows: [ 0, 0, 0 ])

    variation = game.variations.first
    3.times { |reel| variation.reel_strips.create!(position: reel + 1, symbols: %w[ A K W ]) }
    create_entry(variation, [ a ] * 3, 20)
    create_entry(variation, [ k ] * 3, 20)

    assert_equal brute_force(variation.reload), variation.rtp.value
  end

  # --- exactness and reporting -------------------------------------------------

  test "the figure is exact rather than floating point" do
    game = build_game(name: "Exact", reel_count: 3, row_count: 1)
    a = game.symbols.create!(code: "A", position: 1)
    game.symbols.create!(code: "K", position: 2)
    game.paylines.create!(position: 1, rows: [ 0, 0, 0 ])

    variation = game.variations.first
    3.times { |reel| variation.reel_strips.create!(position: reel + 1, symbols: %w[ A K K ]) }
    create_entry(variation, [ a ] * 3, 27)

    # One combination in twenty-seven pays twenty-seven, on a one line stake.
    assert_equal Rational(1), variation.rtp.value
    assert_kind_of Rational, variation.rtp.value
  end

  test "a variation missing its pieces says so rather than returning a figure" do
    game = build_game(name: "Bare", reel_count: 3, row_count: 1)
    game.symbols.create!(code: "A", position: 1)

    result = game.variations.first.rtp

    assert_not_predicate result, :complete?
    assert_match(/no reel strips/, result.to_s)
    assert_match(/no paytable/, result.to_s)
  end

  test "a partly stripped variation is reported as incomplete" do
    game = build_game(name: "Partial", reel_count: 3, row_count: 1)
    a = game.symbols.create!(code: "A", position: 1)
    game.paylines.create!(position: 1, rows: [ 0, 0, 0 ])

    variation = game.variations.first
    variation.reel_strips.create!(position: 1, symbols: %w[ A ])
    create_entry(variation, [ a ] * 3, 5)

    assert_match(/2 reels have no strip/, variation.rtp.to_s)
  end
end
