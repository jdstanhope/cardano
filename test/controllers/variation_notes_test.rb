require "test_helper"

class VariationNotesTest < ActionDispatch::IntegrationTest
  setup do
    @game = SampleGame::RedWhiteAndBlue.build_for(users(:one))
    @variation = @game.variations.first
    sign_in_as users(:one)
  end

  test "branching from a variation writes where it came from" do
    post game_variation_branch_url(@game, @variation)

    branch = @game.variations.order(:number).last
    assert_equal "Branched from variation 01.", branch.note
  end

  test "branching from a checkpoint says which configuration it holds" do
    checkpoint = RtpFigure.record(@variation, @variation.rtp)

    post game_variation_figure_branch_url(@game, @variation, checkpoint)

    branch = @game.variations.order(:number).last
    assert_match(/\ABranched from variation 01, as it was on \d\d \w{3} \d{4} at \d\d:\d\d\.\z/, branch.note)
  end

  test "a variation created from scratch has no note" do
    post game_variations_url(@game)

    assert_nil @game.variations.order(:number).last.note
  end

  test "the note is shown on the variation and can be edited" do
    @variation.update!(note: "Branched from variation 01.")

    get game_variation_url(@game, @variation)
    assert_select "[data-note]", /Branched from variation 01/

    patch game_variation_url(@game, @variation), params: { variation: { note: "Tuned for a 94% band." } }

    assert_redirected_to game_variation_url(@game, @variation)
    assert_equal "Tuned for a 94% band.", @variation.reload.note
  end

  # The trade made deliberately: the field is the designer's, so a fact they overwrite
  # was theirs to overwrite.
  test "the note can be cleared" do
    @variation.update!(note: "Branched from variation 01.")

    patch game_variation_url(@game, @variation), params: { variation: { note: "" } }

    assert_equal "", @variation.reload.note
  end

  test "editing the note leaves the configuration alone" do
    before = @variation.rtp.value

    patch game_variation_url(@game, @variation), params: { variation: { note: "Anything" } }

    assert_equal before, @variation.reload.rtp.value
  end

  test "the game's list of variations shows the note" do
    @variation.update!(note: "The published machine.")

    get game_url(@game)

    assert_select "[data-variation-note]", /The published machine/
  end

  test "another person's variation note cannot be edited" do
    theirs = users(:two).games.create!(name: "Theirs", reel_count: 3, row_count: 1)
    variation = theirs.variations.first

    patch game_variation_url(theirs, variation), params: { variation: { note: "Mine now" } }

    assert_response :not_found
    assert_nil variation.reload.note
  end

  test "signing in is required" do
    reset!

    patch game_variation_url(@game, @variation), params: { variation: { note: "x" } }

    assert_redirected_to new_session_url
  end
end
