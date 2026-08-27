require "test_helper"

class PaytableFormTest < ActiveSupport::TestCase
  setup do
    @game = SampleGame::RedWhiteAndBlue.build_for(users(:one))
    @variation = @game.variations.first
    @red = @game.symbols.find_by(code: "R7")
  end

  # The grid edits one shape — the same symbol repeated — and must not touch the rest.
  # Nothing in the form's interface says so, so a later change has no reason to know it
  # matters. That is exactly why it is asserted rather than left as a comment.
  test "saving the grid leaves combinations it cannot express alone" do
    others = @variation.paytable.reject(&:n_of_a_kind?)
    assert_equal 8, others.length, "the sample is the case this protects"

    assert PaytableForm.new(variation: @variation, payouts: { @red.id.to_s => { "3" => "1500" } }).save

    @variation.reload
    surviving = @variation.paytable.reject(&:n_of_a_kind?)

    assert_equal others.map { |entry| [ entry.id, entry.payout ] }.sort,
                 surviving.map { |entry| [ entry.id, entry.payout ] }.sort,
                 "editing the grid changed a combination it cannot even show"
  end

  test "it edits the N-of-a-kind combination it was pointed at" do
    assert PaytableForm.new(variation: @variation, payouts: { @red.id.to_s => { "3" => "1500" } }).save

    assert_equal 1500, @variation.reload.paytable.find { |entry| entry.sequence == %w[ R7 R7 R7 ] }.payout
  end

  # Clearing a cell removes that combination, and must still take only that one.
  test "clearing a cell removes only that combination" do
    before = @variation.paytable.length

    assert PaytableForm.new(variation: @variation, payouts: { @red.id.to_s => { "3" => "" } }).save

    @variation.reload
    assert_equal before - 1, @variation.paytable.length
    assert_nil @variation.paytable.find { |entry| entry.sequence == %w[ R7 R7 R7 ] }
    assert_equal 8, @variation.paytable.reject(&:n_of_a_kind?).length
  end

  test "a bad cell rejects the whole save, leaving everything as it was" do
    before = @variation.paytable.map { |entry| [ entry.id, entry.payout ] }.sort

    form = PaytableForm.new(variation: @variation, payouts: { @red.id.to_s => { "3" => "not a number" } })

    assert_not form.save
    assert_equal "must be a positive whole number", form.error_for(@red, 3)
    assert_equal before, @variation.reload.paytable.map { |entry| [ entry.id, entry.payout ] }.sort
  end
end
