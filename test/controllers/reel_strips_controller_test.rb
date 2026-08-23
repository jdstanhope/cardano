require "test_helper"

class ReelStripsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @game = games(:five_by_three)
    @variation = variations(:ninety_six)
    sign_in_as @game.user
  end

  def update(reels)
    patch game_variation_reel_strips_url(@game, @variation), params: { reels: reels }
  end

  test "saves every reel at once" do
    update("1" => "A K Q", "2" => "K Q A", "3" => "Q A K", "4" => "A A K", "5" => "K K Q")

    assert_redirected_to game_variation_url(@game, @variation)
    assert_equal 5, @variation.reel_strips.reload.count
    assert_equal %w[ A K Q ], @variation.reel_strips.find_by(position: 1).symbols
  end

  test "accepts codes separated by whitespace, newlines, or commas" do
    update("1" => "A, K\nQ  J")

    assert_equal %w[ A K Q J ], @variation.reel_strips.reload.find_by(position: 1).symbols
  end

  test "matches codes case insensitively against the game's symbols" do
    update("1" => "a k q")

    assert_equal %w[ A K Q ], @variation.reel_strips.reload.find_by(position: 1).symbols,
      "typing a lowercase code should find the symbol, and store its actual code"
  end

  test "reels may differ in length" do
    update("1" => "A K Q J", "2" => "A K")

    strips = @variation.reel_strips.reload
    assert_equal 4, strips.find_by(position: 1).symbols.length
    assert_equal 2, strips.find_by(position: 2).symbols.length
  end

  test "replaces what was there before rather than appending" do
    update("1" => "A K")
    update("1" => "Q")

    assert_equal %w[ Q ], @variation.reel_strips.reload.find_by(position: 1).symbols
  end

  test "reports an unrecognised code against the reel it is on" do
    update("1" => "A K", "2" => "A ZZ K")

    assert_response :unprocessable_entity
    assert_select "[data-reel-error='2']", /ZZ/
    assert_select "[data-reel-error='1']", false, "reel 1 was fine and should not be flagged"
  end

  test "nothing is saved when any reel is rejected" do
    before = @variation.reel_strips.reload.map { |s| [ s.position, s.symbols ] }.sort

    update("1" => "A K", "2" => "ZZ")

    assert_response :unprocessable_entity
    assert_equal before, @variation.reel_strips.reload.map { |s| [ s.position, s.symbols ] }.sort,
      "a rejected save must leave every reel as it was, not just the bad one"
  end

  test "an empty reel clears that strip" do
    update("1" => "")

    assert_nil @variation.reel_strips.reload.find_by(position: 1)
  end

  test "another person's variation cannot be written to" do
    patch game_variation_reel_strips_url(games(:other_game), @variation), params: { reels: { "1" => "A" } }

    assert_response :not_found
  end
end
