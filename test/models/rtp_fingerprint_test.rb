require "test_helper"

# The fingerprint decides whether a change happened. Anything it fails to cover reads
# as "nothing changed" — a wrong answer rather than a missing one — so each input to
# the calculation gets a test that changing it moves the fingerprint.
class RtpFingerprintTest < ActiveSupport::TestCase
  setup do
    @game = SampleGame::RedWhiteAndBlue.build_for(users(:one))
    @variation = @game.variations.first
    @before = RtpFingerprint.for(@variation)
  end

  def assert_changed(message)
    @variation.reload
    assert_not_equal @before, RtpFingerprint.for(@variation.reload), message
  end

  test "the same description fingerprints the same way twice" do
    assert_equal @before, RtpFingerprint.for(Variation.find(@variation.id))
  end

  test "reading in a different order does not change it" do
    @game.symbol_groups.reload
    @game.symbols.reload

    assert_equal @before, RtpFingerprint.for(@variation)
  end

  test "a changed reel strip changes it" do
    strip = @variation.reel_strips.first
    strip.update!(symbols: strip.symbols.rotate)

    assert_changed "a stop moving changes the odds"
  end

  test "a changed payout changes it" do
    @variation.paytable_entries.first.update!(payout: 1)

    assert_changed "a payout is the other half of the figure"
  end

  test "a changed combination changes it" do
    entry = @variation.paytable_entries.first
    entry.matchers.order(:position).first.update!(game_symbol: @game.symbols.find_by(code: "--"))

    assert_changed "what a combination matches decides whether it pays"
  end

  test "reordering a combination changes it" do
    red, white = %w[ R7 W7 ].map { |code| @game.symbols.find_by(code: code) }
    entry = @variation.paytable_entries.new(payout: 5)
    entry.matchers.build(position: 1, game_symbol: red)
    entry.matchers.build(position: 2, game_symbol: white)
    entry.save!
    before = RtpFingerprint.for(@variation.reload)

    first, second = entry.matchers.order(:position).to_a
    first.update!(game_symbol: white)
    second.update!(game_symbol: red)

    assert_not_equal before, RtpFingerprint.for(@variation.reload),
      "order within a combination is part of what it means"
  end

  test "a changed group membership changes it" do
    @game.symbol_groups.find_by(name: "Sevens").game_symbols << @game.symbols.find_by(code: "--")

    assert_changed "a group is named by combinations, so its members decide what they match"
  end

  test "a changed payline changes it" do
    @game.paylines.first.update!(rows: [ 0, 0, 0 ].dup)
    @game.paylines.create!(position: 2, rows: [ 0, 0, 0 ])

    assert_changed "another line is another way to win"
  end

  # Every symbol in this game pays, and one that pays cannot be made wild, so the wild
  # is a new symbol. Taking the reference fingerprint after adding it isolates the flag.
  test "marking a symbol wild changes it" do
    symbol = @game.symbols.create!(code: "XX", name: "Extra", position: 90)
    before = RtpFingerprint.for(@variation.reload)

    symbol.update!(wild: true)

    assert_not_equal before, RtpFingerprint.for(@variation.reload),
      "a wild substitutes, which pays combinations that otherwise would not"
  end

  test "excluding a symbol from a wild changes it" do
    wild = @game.symbols.create!(code: "WW", name: "Wild", position: 90)
    before = RtpFingerprint.for(@variation.reload)

    wild.wild_exclusions.create!(excluded: @game.symbols.find_by(code: "R7"))

    assert_not_equal before, RtpFingerprint.for(@variation.reload),
      "what a wild refuses to stand in for changes what pays"
  end

  test "the reel window changes it" do
    @game.update!(row_count: 3)

    assert_changed "the window decides how many symbols are in play"
  end

  test "the win mechanic changes it" do
    @game.paylines.destroy_all
    @game.update!(win_mechanic: "ways")

    assert_changed "lines and ways select combinations differently"
  end

  # Renaming a symbol does not change any figure, so it must not read as a change.
  test "a display name does not change it" do
    @game.symbols.find_by(code: "R7").update!(name: "Scarlet Seven")

    assert_equal @before, RtpFingerprint.for(@variation.reload)
  end

  test "another variation of the same game fingerprints differently" do
    other = @game.variations.create!(number: 2)

    assert_not_equal @before, RtpFingerprint.for(other),
      "an empty variation is not the same description as a full one"
  end
end
