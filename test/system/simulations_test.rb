require "application_system_test_case"

class SimulationsTest < ApplicationSystemTestCase
  setup do
    @game = SampleGame::RedWhiteAndBlue.build_for(users(:one))
    @variation = @game.variations.first
    Calculation.start(@variation).perform
    sign_in_through_the_form(users(:one))
  end

  test "a simulation can be asked for, and joins the list as queued" do
    visit game_variation_path(@game, @variation)
    assert_selector "[data-calculation]", count: 1

    open_the_form
    click_on "Start sampling"

    assert_text "Sampling"
    assert_selector "[data-calculation]", count: 2
    assert_selector "[data-calculation] [data-state='queued']"
  end

  test "the precision asked for is the precision run to" do
    visit game_variation_path(@game, @variation)

    open_the_form
    select "±0.05 points", from: "Precision"
    select "99%", from: "Confidence"
    select "1,000,000,000 spins", from: "Ceiling"
    click_on "Start sampling"

    assert_text "Sampling"
    calculation = @variation.calculations.newest_first.first

    assert_equal 5, calculation.precision_points
    assert_equal 99, calculation.confidence
    assert_equal 1_000_000_000, calculation.ceiling
  end

  # The reason the seed is recorded at all: a figure somebody disputes has to be
  # reproducible, and reproducing it is something they do from this page.
  test "a run can be repeated by giving it the seed of an earlier one" do
    first = Calculation.simulate(@variation, precision: short, seed: 4_242)
    first.perform

    visit game_variation_path(@game, @variation)
    open_the_form
    fill_in "Seed", with: "4242"
    click_on "Start sampling"

    assert_text "Sampling"
    assert_equal 4_242, @variation.calculations.newest_first.first.seed
  end

  test "a run in flight refuses a second rather than queueing it" do
    Calculation.simulate(@variation, precision: short, seed: 1)

    visit game_variation_path(@game, @variation)
    open_the_form
    click_on "Start sampling"

    assert_text "Already working that out"
  end

  private
    def short = Rtp::Precision.new(points: 0.01, confidence: 95, ceiling: 20_000)

    def open_the_form = find("[data-simulation-toggle]").click
end
