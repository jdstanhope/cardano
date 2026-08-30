require "test_helper"

class RtpHistoryTest < ActionDispatch::IntegrationTest
  # The figure is worked out by a run rather than during the request, so a test that
  # wants to see one has to let the run happen.
  include ActiveJob::TestHelper

  setup do
    @game = SampleGame::RedWhiteAndBlue.build_for(users(:one))
    @variation = @game.variations.first
    sign_in_as users(:one)
  end

  def rtp_section = css_select("[data-rtp]").first.text

  def view(variation = @variation)
    perform_enqueued_jobs { get game_variation_url(@game, variation) }
  end

  # A variation nobody has changed has nothing to compare against, and inventing a
  # baseline would be claiming a change that never happened.
  test "a first figure shows no comparison and no history" do
    view

    assert_response :success
    assert_match(/86\.58%/, rtp_section)
    assert_no_match(/before your last change/, rtp_section)
    assert_select "[data-rtp] details", 0
  end

  test "a change shows what the figure was before it" do
    view
    @variation.paytable_entries.find_by(payout: 2400).update!(payout: 4800)

    view

    assert_match(/was 86\.58% before your last change/, rtp_section)
  end

  test "the difference is shown in percentage points, signed" do
    view
    before = @variation.latest_rtp_figure

    @variation.paytable_entries.find_by(payout: 2400).update!(payout: 4800)
    view

    points = @variation.reload.latest_rtp_figure.points_from(before)
    assert_operator points, :>, 0
    assert_match(/\+#{format("%.2f", points)} points/, rtp_section)
  end

  test "a change that lowers the figure is shown as a fall" do
    view

    @variation.paytable_entries.find_by(payout: 2400).update!(payout: 100)
    view

    assert_match(/-\d+\.\d\d points/, rtp_section)
  end

  test "looking again without changing anything keeps the same comparison" do
    view
    @variation.paytable_entries.find_by(payout: 2400).update!(payout: 4800)
    view
    first_reading = rtp_section

    assert_no_difference -> { @variation.rtp_figures.count } do
      view
    end

    assert_equal first_reading, rtp_section, "a second look reported a different change"
  end

  test "the history lists every figure once more than one exists" do
    view

    [ 4800, 2400, 1200 ].each do |payout|
      @variation.paytable_entries.find_by(payout: @variation.paytable_entries.maximum(:payout)).update!(payout: payout)
      view
    end

    assert_equal 4, @variation.rtp_figures.count
    assert_select "[data-rtp] [data-figure]", 4
    assert_match(/History · 4 figures/, rtp_section)
  end

  test "an incomplete description offers no figure and no comparison" do
    empty = @game.variations.create!(number: 2)

    view(empty)

    assert_response :success
    assert_match(/Not yet/, rtp_section)
    assert_no_match(/before your last change/, rtp_section)
  end

  # Beside a figure that predates the latest edit, a difference would read as the effect
  # of that edit — which is the one thing not yet worked out.
  test "no comparison is shown while the figure is out of date" do
    view
    @variation.paytable_entries.find_by(payout: 2400).update!(payout: 4800)

    get game_variation_url(@game, @variation)

    assert_match(/out of date/, rtp_section)
    assert_no_match(/before your last change/, rtp_section)
  end

  # "Was 87.49%" says the figure moved; this says what moved it.
  test "the history says what changed between one figure and the last" do
    view
    @variation.paytable_entries.find_by(payout: 2400).update!(payout: 4800)
    view

    assert_select "[data-changes]", /R7 W7 B7: 2400 → 4800/
  end

  # A change to the game is shared with every other variation, so a reader should not
  # take it for something done here.
  test "a change belonging to the game is marked as the game's" do
    view
    @game.paylines.create!(position: 2, rows: [ 0, 0, 0 ])
    view

    assert_select "[data-changes]", /Paylines: 1 → 2/
    assert_select "[data-changes]", /shared with its other variations/
  end
end
