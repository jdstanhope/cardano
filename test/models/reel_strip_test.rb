require "test_helper"

class ReelStripTest < ActiveSupport::TestCase
  setup do
    @variation = variations(:ninety_six)
  end

  test "requires a position and at least one stop" do
    strip = ReelStrip.new(variation: @variation, symbols: [])

    assert_not strip.valid?
    assert strip.errors.of_kind?(:position, :blank)
    assert_includes strip.errors[:symbols], "must have at least one stop"
  end

  test "positions are unique within a variation" do
    duplicate = ReelStrip.new(variation: @variation, position: reel_strips(:reel_one).position, symbols: %w[ A ])

    assert_not duplicate.valid?
  end

  test "the position must be a reel the game actually has" do
    assert ReelStrip.new(variation: @variation, position: 5, symbols: %w[ A ]).valid?
    assert_not ReelStrip.new(variation: @variation, position: 6, symbols: %w[ A ]).valid?,
      "a five reel game has no sixth reel"
    assert_not ReelStrip.new(variation: @variation, position: 0, symbols: %w[ A ]).valid?,
      "reels are numbered from one"
  end

  test "every stop must be one of the game's symbols" do
    strip = ReelStrip.new(variation: @variation, position: 3, symbols: %w[ A K Z ])

    assert_not strip.valid?
    assert_match(/Z/, strip.errors[:symbols].to_sentence)
  end

  test "a code from another game is not one of this game's symbols" do
    # `other_game` also has an "A", but a strip here may only use its own game's codes.
    strip = ReelStrip.new(variation: @variation, position: 3, symbols: %w[ A ])
    assert strip.valid?, "the game's own A is fine"

    outsider = ReelStrip.new(variation: variations(:ninety_six), position: 4, symbols: %w[ ZZ ])
    assert_not outsider.valid?
  end

  test "reels may differ in length" do
    assert_not_equal reel_strips(:reel_one).symbols.length, reel_strips(:reel_two).symbols.length
    assert reel_strips(:reel_one).valid?
    assert reel_strips(:reel_two).valid?
  end

  test "reports how many stops it has" do
    assert_equal 6, reel_strips(:reel_one).stop_count
    assert_equal 4, reel_strips(:reel_two).stop_count
  end

  test "cannot be validated without a variation to measure against" do
    assert_not ReelStrip.new(position: 1, symbols: %w[ A ]).valid?
  end
end
