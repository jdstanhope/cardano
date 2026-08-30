require "test_helper"

class BranchesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @game = SampleGame::RedWhiteAndBlue.build_for(users(:one))
    @variation = @game.variations.first
    sign_in_as users(:one)
  end

  test "copying a variation lands on the new one, holding what the old one holds" do
    assert_difference -> { @game.variations.count }, 1 do
      post game_variation_branch_url(@game, @variation)
    end

    branch = @game.variations.order(:number).last
    assert_redirected_to game_variation_url(@game, branch)
    assert_equal 2, branch.number
    assert_equal @variation.rtp.value, branch.rtp.value
  end

  test "the variation copied from is untouched" do
    before = @variation.rtp.value

    post game_variation_branch_url(@game, @variation)

    branch = @game.variations.order(:number).last
    branch.paytable_entries.find_by(payout: 2400).update!(payout: 9)

    assert_equal before, @variation.reload.rtp.value
  end

  test "the new variation works its own figure out" do
    assert_difference -> { Calculation.count }, 1 do
      post game_variation_branch_url(@game, @variation)
    end
  end

  test "a game with no free variation number is refused with the reason" do
    (2..99).each { |number| @game.variations.create!(number: number) }

    assert_no_difference -> { @game.variations.count } do
      post game_variation_branch_url(@game, @variation)
    end

    assert_match(/already has all 99 variations/, flash[:alert])
  end

  test "another person's variation cannot be copied" do
    theirs = users(:two).games.create!(name: "Theirs", reel_count: 3, row_count: 1)

    assert_no_difference -> { Variation.count } do
      post game_variation_branch_url(theirs, theirs.variations.first)
    end

    assert_response :not_found
  end

  test "signing in is required" do
    reset!

    post game_variation_branch_url(@game, @variation)

    assert_redirected_to new_session_url
  end

  test "the variation page offers the copy" do
    get game_variation_url(@game, @variation)

    assert_select "form[action=?]", game_variation_branch_path(@game, @variation)
  end
end
