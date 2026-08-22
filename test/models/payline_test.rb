require "test_helper"

class PaylineTest < ActiveSupport::TestCase
  setup do
    @game = games(:five_by_three)
  end

  test "requires a position and belongs to a game" do
    payline = Payline.new(game: @game, rows: [ 0, 0, 0, 0, 0 ])

    assert_not payline.valid?
    assert payline.errors.of_kind?(:position, :blank)
  end

  test "positions are unique within a game" do
    duplicate = Payline.new(game: @game, position: paylines(:centre).position, rows: [ 0, 0, 0, 0, 0 ])

    assert_not duplicate.valid?
  end

  test "takes exactly one row per reel" do
    too_few = Payline.new(game: @game, position: 9, rows: [ 0, 0, 0 ])
    too_many = Payline.new(game: @game, position: 9, rows: [ 0, 0, 0, 0, 0, 0 ])

    assert_not too_few.valid?, "three rows across five reels should be rejected"
    assert_not too_many.valid?, "six rows across five reels should be rejected"
    assert_match(/5/, too_few.errors[:rows].to_sentence)
  end

  test "rejects a row outside the window" do
    above = Payline.new(game: @game, position: 9, rows: [ 2, 0, 0, 0, 0 ])
    below = Payline.new(game: @game, position: 9, rows: [ 0, 0, -2, 0, 0 ])

    assert_not above.valid?, "row 2 does not exist in a three row window"
    assert_not below.valid?, "row -2 does not exist in a three row window"
  end

  test "accepts every row the window actually has" do
    payline = Payline.new(game: @game, position: 9, rows: [ 1, 0, -1, 0, 1 ])

    assert payline.valid?, payline.errors.full_messages.to_sentence
  end

  test "the centre line is valid for every window height, odd or even" do
    (1..6).each do |height|
      game = Game.create!(user: users(:one), name: "Window #{height}", reel_count: 5, row_count: height)
      payline = Payline.new(game: game, position: 1, rows: [ 0, 0, 0, 0, 0 ])

      assert payline.valid?, "centre line should be valid in a #{height} row window"
    end
  end

  test "an even window accepts one row above centre and two below" do
    game = games(:five_by_four)

    assert Payline.new(game: game, position: 1, rows: [ 1, 1, 1, 1, 1 ]).valid?
    assert Payline.new(game: game, position: 2, rows: [ -2, -2, -2, -2, -2 ]).valid?
    assert_not Payline.new(game: game, position: 3, rows: [ 2, 0, 0, 0, 0 ]).valid?,
      "row 2 is above the top of a four row window"
  end

  test "cannot be validated without a game to measure against" do
    payline = Payline.new(position: 1, rows: [ 0, 0, 0, 0, 0 ])

    assert_not payline.valid?
    assert payline.errors.of_kind?(:game, :blank)
  end
end
