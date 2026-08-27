require "test_helper"

class RtpHistoryTest < ActionDispatch::IntegrationTest
  setup do
    @game = SampleGame::RedWhiteAndBlue.build_for(users(:one))
    @variation = @game.variations.first
    sign_in_as users(:one)
  end

  def rtp_section = css_select("[data-rtp]").first.text

  # A variation nobody has changed has nothing to compare against, and inventing a
  # baseline would be claiming a change that never happened.
  test "a first figure shows no comparison and no history" do
    get game_variation_url(@game, @variation)

    assert_response :success
    assert_match(/86\.58%/, rtp_section)
    assert_no_match(/before your last change/, rtp_section)
    assert_select "[data-rtp] details", 0
  end

  test "a change shows what the figure was before it" do
    get game_variation_url(@game, @variation)
    @variation.paytable_entries.find_by(payout: 2400).update!(payout: 4800)

    get game_variation_url(@game, @variation)

    assert_match(/was 86\.58% before your last change/, rtp_section)
  end

  test "the difference is shown in percentage points, signed" do
    get game_variation_url(@game, @variation)
    before = @variation.latest_rtp_figure

    @variation.paytable_entries.find_by(payout: 2400).update!(payout: 4800)
    get game_variation_url(@game, @variation)

    points = @variation.reload.latest_rtp_figure.points_from(before)
    assert_operator points, :>, 0
    assert_match(/\+#{format("%.2f", points)} points/, rtp_section)
  end

  test "a change that lowers the figure is shown as a fall" do
    get game_variation_url(@game, @variation)

    @variation.paytable_entries.find_by(payout: 2400).update!(payout: 100)
    get game_variation_url(@game, @variation)

    assert_match(/-\d+\.\d\d points/, rtp_section)
  end

  test "looking again without changing anything keeps the same comparison" do
    get game_variation_url(@game, @variation)
    @variation.paytable_entries.find_by(payout: 2400).update!(payout: 4800)
    get game_variation_url(@game, @variation)
    first_reading = rtp_section

    assert_no_difference -> { @variation.rtp_figures.count } do
      get game_variation_url(@game, @variation)
    end

    assert_equal first_reading, rtp_section, "a second look reported a different change"
  end

  test "the history lists every figure once more than one exists" do
    get game_variation_url(@game, @variation)

    [ 4800, 2400, 1200 ].each do |payout|
      @variation.paytable_entries.find_by(payout: @variation.paytable_entries.maximum(:payout)).update!(payout: payout)
      get game_variation_url(@game, @variation)
    end

    assert_equal 4, @variation.rtp_figures.count
    assert_select "[data-rtp] details ol li", 4
    assert_match(/History · 4 figures/, rtp_section)
  end

  test "an incomplete description offers no figure and no comparison" do
    empty = @game.variations.create!(number: 2)

    get game_variation_url(@game, empty)

    assert_response :success
    assert_match(/Not yet/, rtp_section)
    assert_no_match(/before your last change/, rtp_section)
  end
end
