require "test_helper"

class VariationTest < ActiveSupport::TestCase
  setup do
    @game = games(:five_by_three)
  end

  test "requires a name, unique within its game" do
    assert_not Variation.new(game: @game).valid?
    assert_not Variation.new(game: @game, name: variations(:ninety_six).name).valid?
  end

  test "a target band is optional" do
    assert variations(:untargeted).valid?
  end

  test "a target band is given as a pair or not at all" do
    only_min = Variation.new(game: @game, name: "min only", target_rtp_min: 9600)
    only_max = Variation.new(game: @game, name: "max only", target_rtp_max: 9650)

    assert_not only_min.valid?
    assert_not only_max.valid?
  end

  test "the bottom of the band cannot exceed the top" do
    inverted = Variation.new(game: @game, name: "inverted", target_rtp_min: 9650, target_rtp_max: 9600)

    assert_not inverted.valid?
  end

  test "a band may be a single point" do
    exact = Variation.new(game: @game, name: "exact", target_rtp_min: 9600, target_rtp_max: 9600)

    assert exact.valid?, exact.errors.full_messages.to_sentence
  end

  test "targets are basis points, so they are stored exactly" do
    variation = variations(:ninety_six)

    assert_equal 9600, variation.target_rtp_min
    assert_kind_of Integer, variation.target_rtp_min
    assert_equal "96.00%", variation.target_rtp_min_percentage
  end
end
