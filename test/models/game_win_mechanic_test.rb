require "test_helper"

class GameWinMechanicTest < ActiveSupport::TestCase
  setup do
    @game = games(:five_by_three)
  end

  test "a game pays by lines unless it says otherwise" do
    fresh = users(:one).games.create!(name: "Fresh", reel_count: 5, row_count: 3)

    assert_predicate fresh, :pays_by_lines?
    assert_not_predicate fresh, :pays_by_ways?
  end

  test "an unknown mechanic is rejected" do
    @game.win_mechanic = "clusters"

    assert_not @game.valid?
  end

  test "switching to ways is refused while paylines exist" do
    assert_predicate @game.paylines, :any?

    assert_not @game.update(win_mechanic: "ways")
    assert_match(/remove them first/i, @game.errors[:win_mechanic].to_sentence)
    assert_predicate @game.reload, :pays_by_lines?
  end

  test "switching to ways works once the paylines are gone" do
    @game.paylines.destroy_all

    assert @game.update(win_mechanic: "ways")
    assert_predicate @game.reload, :pays_by_ways?
  end

  test "a ways game cannot then be given a payline" do
    @game.paylines.destroy_all
    @game.update!(win_mechanic: "ways")

    payline = @game.paylines.new(position: 1, rows: [ 0, 0, 0, 0, 0 ])

    assert payline.valid?, "the payline itself is fine"
    assert_not @game.reload.tap { |g| g.paylines.create!(position: 1, rows: [ 0, 0, 0, 0, 0 ]) }.valid?,
      "but the game is not, while it pays by ways"
  end

  test "the ways count follows from the window" do
    @game.paylines.destroy_all
    @game.update!(win_mechanic: "ways")

    assert_equal 243, @game.ways_count

    @game.update!(row_count: 4)
    assert_equal 1024, @game.ways_count
  end

  test "the mechanic object matches what the game declares" do
    assert_kind_of WinMechanic::Lines, @game.win_mechanic_for_evaluation

    @game.paylines.destroy_all
    @game.update!(win_mechanic: "ways")

    assert_kind_of WinMechanic::Ways, @game.reload.win_mechanic_for_evaluation
  end
end
