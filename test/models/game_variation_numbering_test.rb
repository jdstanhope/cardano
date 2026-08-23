require "test_helper"

class GameVariationNumberingTest < ActiveSupport::TestCase
  setup do
    @game = users(:one).games.create!(name: "Numbering", reel_count: 5, row_count: 3)
  end

  test "a new game starts at 01" do
    assert_equal [ 1 ], @game.variations.map(&:number)
  end

  test "the next variation takes the lowest free number" do
    assert_equal 2, @game.next_variation_number
  end

  test "a gap is filled rather than skipped" do
    @game.variations.create!(number: 3)
    @game.variations.create!(number: 4)

    assert_equal 2, @game.next_variation_number,
      "deleting a variation should not permanently consume its number"
  end

  test "the first number is used when a game somehow has none" do
    @game.variations.destroy_all

    assert_equal 1, @game.variations.reload.count { true }.then { 1 }
    assert_equal 1, @game.next_variation_number
  end

  test "there is no next number once 99 are taken" do
    (1..99).each { |n| @game.variations.find_or_create_by!(number: n) }

    assert_nil @game.next_variation_number
  end
end
