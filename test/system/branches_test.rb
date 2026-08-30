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
    find("[data-history-toggle]").click
    within("[data-figure='#{checkpoint.id}']") { click_on "Branch" }

    assert_selector "h1", text: "Variation 02"
    assert_text "01 is unchanged"

    assert_equal 2400, @game.variations.find_by(number: 2).paytable.find { |entry| entry.sequence == %w[ R7 W7 B7 ] }.payout
    assert_equal 9, @variation.reload.paytable.find { |entry| entry.sequence == %w[ R7 W7 B7 ] }.payout
  end

  # A variation should be able to account for itself a week later, when the flash
  # message that explained it is long gone.
  test "a branched variation says where it came from, and the note can be rewritten" do
    visit game_variation_path(@game, @variation)
    click_on "Copy to a new variation"

    assert_selector "[data-note]", text: "Branched from variation 01."

    find("[data-note-toggle]").click
    fill_in "What this variation is for", with: "Trying a shorter reel 2."
    click_on "Save note"

    assert_text "Note saved"
    assert_selector "[data-note]", text: "Trying a shorter reel 2."

    # And it is on the game page, which is where you go looking.
    click_on @game.name
    assert_selector "[data-variation-note]", text: "Trying a shorter reel 2."
  end
end
