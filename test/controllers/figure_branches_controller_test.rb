require "test_helper"

class FigureBranchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @game = SampleGame::RedWhiteAndBlue.build_for(users(:one))
    @variation = @game.variations.first
    @checkpoint = RtpFigure.record(@variation, @variation.rtp)
    sign_in_as users(:one)
  end

  # Keeping a configuration you have moved past, rather than returning to it.
  test "branching a checkpoint makes a variation holding that configuration" do
    @variation.paytable_entries.find_by(payout: 2400).update!(payout: 9)
    assert_not_equal @checkpoint.value, @variation.reload.rtp.value

    assert_difference -> { @game.variations.count }, 1 do
      post game_variation_figure_branch_url(@game, @variation, @checkpoint)
    end

    branch = @game.variations.order(:number).last
    assert_redirected_to game_variation_url(@game, branch)
    assert_equal @checkpoint.value, branch.rtp.value
  end

  test "the variation branched from keeps its current configuration and records nothing" do
    @variation.paytable_entries.find_by(payout: 2400).update!(payout: 9)
    current = @variation.reload.rtp.value

    assert_no_difference -> { @variation.rtp_figures.count } do
      post game_variation_figure_branch_url(@game, @variation, @checkpoint)
    end

    assert_equal current, @variation.reload.rtp.value
  end

  test "a checkpoint naming something deleted is refused with the reason" do
    @game.symbol_groups.find_by(name: "Bars").destroy!

    assert_no_difference -> { Variation.count } do
      post game_variation_figure_branch_url(@game, @variation, @checkpoint)
    end

    assert_match(/group Bars no longer exist/i, flash[:alert])
  end

  test "a figure from another variation is not found" do
    other = @game.variations.create!(number: 2)

    post game_variation_figure_branch_url(@game, other, @checkpoint)

    assert_response :not_found
  end

  test "the history offers a branch beside the restore" do
    @variation.reel_strips.first.update!(symbols: %w[ R7 R7 R7 ])
    RtpFigure.record(@variation.reload, @variation.rtp)

    get game_variation_url(@game, @variation)

    assert_select "form[action=?]", game_variation_figure_branch_path(@game, @variation, @checkpoint)
  end
end
