require "test_helper"

class RestorationsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @game = SampleGame::RedWhiteAndBlue.build_for(users(:one))
    @variation = @game.variations.first
    @checkpoint = RtpFigure.record(@variation, @variation.rtp)
    sign_in_as users(:one)
  end

  def path = new_game_variation_figure_restoration_path(@game, @variation, @checkpoint)
  def url = new_game_variation_figure_restoration_url(@game, @variation, @checkpoint)
  def action = game_variation_figure_restoration_url(@game, @variation, @checkpoint)

  test "it says what will be put back before doing anything" do
    assert_no_difference -> { @variation.reel_strips.count } do
      get url
    end

    assert_response :success
    assert_select "[data-restoring]", /3 reel strips/
    assert_select "[data-restoring]", /15 paytable combinations/
  end

  test "restoring puts the strips and paytable back" do
    before = @variation.rtp.value
    @variation.reel_strips.first.update!(symbols: %w[ R7 R7 R7 ])
    @variation.paytable_entries.find_by(payout: 2400).update!(payout: 9)

    post action

    assert_redirected_to game_variation_url(@game, @variation)
    assert_equal before, @variation.reload.rtp.value
  end

  # A restore is a change like any other, which is what leaves the configuration being
  # left behind still in the history and still restorable.
  test "restoring records a figure of its own" do
    @variation.reel_strips.first.update!(symbols: %w[ R7 R7 R7 ])
    detour = RtpFigure.record(@variation.reload, @variation.rtp)

    assert_difference -> { @variation.rtp_figures.count }, 1 do
      perform_enqueued_jobs { post action }
    end

    assert_equal @checkpoint.value, @variation.reload.latest_rtp_figure.value
    assert_not_nil RtpFigure.find_by(id: detour.id), "the configuration left behind is still in the history"
  end

  test "it warns that the figure will differ when the game has moved since" do
    @game.paylines.create!(position: 2, rows: [ 0, 0, 0 ])

    get url

    assert_select "[data-leaving-alone]", /Paylines: 1 → 2/
    assert_select "[data-leaving-alone]", /will not be/
  end

  test "no warning when the game is untouched" do
    @variation.reel_strips.first.update!(symbols: %w[ R7 R7 R7 ])

    get url

    assert_select "[data-leaving-alone]", 0
  end

  test "a configuration naming something deleted is refused, and says why" do
    @game.symbol_groups.find_by(name: "Bars").destroy!

    get url

    assert_response :success
    assert_select "[data-refused]", /group Bars no longer exist/i
    assert_select "form[action=?]", game_variation_figure_restoration_path(@game, @variation, @checkpoint), 0,
      "there is nothing to submit when it cannot be restored"
  end

  test "posting a refused restoration changes nothing" do
    @game.symbol_groups.find_by(name: "Bars").destroy!
    before = @variation.paytable.length

    post action

    assert_response :unprocessable_entity
    assert_equal before, @variation.reload.paytable.length
  end

  test "the game is left alone" do
    @game.paylines.create!(position: 2, rows: [ 0, 0, 0 ])

    post action

    assert_equal 2, @game.reload.paylines.count
  end

  test "another person's variation is not found" do
    theirs = users(:two).games.create!(name: "Theirs", reel_count: 3, row_count: 1)

    get new_game_variation_figure_restoration_url(theirs, theirs.variations.first, @checkpoint)

    assert_response :not_found
  end

  # The figure is looked up through the variation, so one belonging to a different
  # variation is not reachable even by somebody who owns both.
  test "a figure from another variation is not found" do
    other = @game.variations.create!(number: 2)

    get new_game_variation_figure_restoration_url(@game, other, @checkpoint)

    assert_response :not_found
  end

  test "signing in is required" do
    reset!

    post action

    assert_redirected_to new_session_url
  end

  test "the history offers a restore for figures that kept their configuration" do
    @variation.reel_strips.first.update!(symbols: %w[ R7 R7 R7 ])
    RtpFigure.record(@variation.reload, @variation.rtp)

    get game_variation_url(@game, @variation)

    assert_select "a[href=?]", path
  end
end
