require "test_helper"

class VariationTest < ActiveSupport::TestCase
  setup do
    @game = games(:five_by_three)
  end

  test "is identified by a number, unique within its game" do
    assert_not Variation.new(game: @game).valid?
    assert_not Variation.new(game: @game, number: variations(:ninety_six).number).valid?
  end

  test "the same number may be used in a different game" do
    assert Variation.new(game: games(:other_game), number: variations(:ninety_six).number).valid?
  end

  test "numbers run from 1 to 99" do
    assert Variation.new(game: @game, number: 99).valid?
    assert_not Variation.new(game: @game, number: 0).valid?
    assert_not Variation.new(game: @game, number: 100).valid?
  end

  test "displays padded to two digits" do
    assert_equal "01", Variation.new(number: 1).label
    assert_equal "09", Variation.new(number: 9).label
    assert_equal "10", Variation.new(number: 10).label
    assert_equal "99", Variation.new(number: 99).label
  end

  test "orders by number rather than alphabetically" do
    # "10" sorts before "2" as a string; as a number it does not.
    @game.variations.destroy_all
    [ 10, 2, 1 ].each { |n| @game.variations.create!(number: n) }

    assert_equal [ 1, 2, 10 ], @game.variations.reload.map(&:number)
  end

  test "a target band is optional" do
    assert variations(:untargeted).valid?
  end

  test "a target band is given as a pair or not at all" do
    assert_not Variation.new(game: @game, number: 50, target_rtp_min: 9600).valid?
    assert_not Variation.new(game: @game, number: 50, target_rtp_max: 9650).valid?
  end

  test "the bottom of the band cannot exceed the top" do
    assert_not Variation.new(game: @game, number: 50, target_rtp_min: 9650, target_rtp_max: 9600).valid?
  end

  test "a band may be a single point" do
    assert Variation.new(game: @game, number: 50, target_rtp_min: 9600, target_rtp_max: 9600).valid?
  end

  test "targets are basis points, so they are stored exactly" do
    variation = variations(:ninety_six)

    assert_equal 9600, variation.target_rtp_min
    assert_kind_of Integer, variation.target_rtp_min
    assert_equal "96.00%", variation.target_rtp_min_percentage
  end
end
