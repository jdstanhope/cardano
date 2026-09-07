require "test_helper"

class SimulationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @game = SampleGame::RedWhiteAndBlue.build_for(users(:one))
    @variation = @game.variations.first
    sign_in_as users(:one)
  end

  test "asking for a simulation queues one" do
    assert_difference -> { @variation.calculations.count }, 1 do
      start
    end

    calculation = @variation.calculations.newest_first.first

    assert_equal Rtp::SAMPLED.to_s, calculation.computed_by
    assert_predicate calculation, :in_flight?
    assert_redirected_to game_variation_path(@game, @variation)
  end

  test "it runs to the precision, confidence and ceiling that were asked for" do
    start points: "0.05", confidence: "99", ceiling: "1000000000"
    calculation = @variation.calculations.newest_first.first

    assert_equal 5, calculation.precision_points, "stored in basis points"
    assert_equal 99, calculation.confidence
    assert_equal 1_000_000_000, calculation.ceiling
  end

  # The ceiling is the only thing bounding how long a run holds a worker, so it is chosen
  # from a list rather than typed. A request naming anything else is not an error to
  # report — it is a request nobody could have made through the page, and it gets the
  # least work of the set.
  test "a precision, confidence or ceiling that is not on offer falls back to the default" do
    start points: "0.000001", confidence: "42", ceiling: "999999999999"
    calculation = @variation.calculations.newest_first.first

    assert_equal 50, calculation.precision_points
    assert_equal 95, calculation.confidence
    assert_equal Rtp::Precision::DEFAULTS[:ceiling], calculation.ceiling
  end

  test "a seed can be given, so a disputed figure can be run again" do
    start seed: "12345"

    assert_equal 12_345, @variation.calculations.newest_first.first.seed
  end

  test "a seed nobody could have produced is ignored rather than refused" do
    start seed: "not a number"

    assert_not_nil @variation.calculations.newest_first.first.seed
  end

  test "a seed past the range the tool invents from is ignored" do
    start seed: (Calculation::SEEDS + 1).to_s

    assert_operator @variation.calculations.newest_first.first.seed, :<, Calculation::SEEDS
  end

  test "an incomplete description is refused, and says what is missing" do
    empty = @game.variations.create!(number: 2)

    assert_no_difference -> { empty.calculations.count } do
      post game_variation_simulation_path(@game, empty)
    end

    assert_match(/no reel strips/, flash[:alert])
  end

  test "a second run is refused while one is already going" do
    Calculation.start(@variation)

    assert_no_difference -> { @variation.calculations.count } do
      start
    end
  end

  test "another person's variation is not found" do
    theirs = users(:two).games.create!(name: "Theirs", reel_count: 3, row_count: 1)

    assert_no_difference -> { Calculation.count } do
      post game_variation_simulation_path(theirs, theirs.variations.first)
    end

    assert_response :not_found
  end

  private
    def start(**parameters)
      post game_variation_simulation_path(@game, @variation), params: parameters
    end
end
