require "application_system_test_case"

class BranchesTest < ApplicationSystemTestCase
  setup do
    @game = SampleGame::RedWhiteAndBlue.build_for(users(:one))
    @variation = @game.variations.first
    Calculation.start(@variation).perform
    sign_in_through_the_form(users(:one))
  end

  test "a variation can be copied, and changes to the copy leave the original alone" do
    visit game_variation_path(@game, @variation)

    click_on "Copy to a new variation"

    assert_selector "h1", text: "Variation 02"
    assert_text "holds what 01 holds"

    branch = @game.variations.find_by(number: 2)
    branch.paytable_entries.find_by(payout: 2400).update!(payout: 9)

    assert_equal 2400, @variation.reload.paytable.find { |entry| entry.sequence == %w[ R7 W7 B7 ] }.payout
  end

  # Keeping a configuration you have moved past, rather than going back to it.
  test "a checkpoint can be branched into its own variation" do
    checkpoint = @variation.latest_rtp_figure
    @variation.paytable_entries.find_by(payout: 2400).update!(payout: 9)
    Calculation.start(@variation.reload).perform

    visit game_variation_path(@game, @variation)
    find("summary").click
    within("[data-figure='#{checkpoint.id}']") { click_on "Branch" }

    assert_selector "h1", text: "Variation 02"
    assert_text "01 is unchanged"

    assert_equal 2400, @game.variations.find_by(number: 2).paytable.find { |entry| entry.sequence == %w[ R7 W7 B7 ] }.payout
    assert_equal 9, @variation.reload.paytable.find { |entry| entry.sequence == %w[ R7 W7 B7 ] }.payout
  end
end
