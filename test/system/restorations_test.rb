require "application_system_test_case"

class RestorationsTest < ApplicationSystemTestCase
  setup do
    @game = SampleGame::RedWhiteAndBlue.build_for(users(:one))
    @variation = @game.variations.first
    Calculation.start(@variation).perform
    sign_in_through_the_form(users(:one))
  end

  # Going back and then forward again: the point of an append-only history is that
  # neither direction throws anything away.
  # Rows are addressed by figure rather than by position: what matters is that each
  # configuration stays reachable, not where it happens to sit in the list.
  test "a configuration can be restored, and the one left behind restored back" do
    checkpoint = @variation.latest_rtp_figure

    @variation.paytable_entries.find_by(payout: 2400).update!(payout: 9)
    Calculation.start(@variation.reload).perform
    detour = @variation.reload.latest_rtp_figure
    assert_not_equal checkpoint.id, detour.id

    restore(checkpoint)
    assert_selector "h1", text: "Restore 86.58%"
    assert_text "3 reel strips"
    confirm

    assert_equal 2400, @variation.reload.paytable.find { |entry| entry.sequence == %w[ R7 W7 B7 ] }.payout

    # And back again: the configuration left behind is still there to return to.
    restore(detour)
    confirm

    assert_equal 9, @variation.reload.paytable.find { |entry| entry.sequence == %w[ R7 W7 B7 ] }.payout
  end

  private
    def restore(figure)
      visit game_variation_path(@game, @variation)
      find("[data-history-toggle]").click
      within("[data-figure='#{figure.id}']") { click_on "Restore" }
    end

    def confirm
      click_on "Restore this configuration"
      assert_text "Restored the configuration"
    end
end
