require "application_system_test_case"

# A reel is entered as a column of stops, and nearly all of that is browser behaviour:
# what Enter does, what Backspace on an empty stop does, where a pasted column lands.
# None of it is visible to the server until the form is saved.
class ReelStripsTest < ApplicationSystemTestCase
  setup do
    @game = games(:five_by_three)
    @variation = variations(:ninety_six)
    sign_in_through_the_form @game.user
    visit game_variation_path(@game, @variation)
    assert_selector "h1", text: "Variation"
  end

  # Addressed by aria-label rather than by label text: the label is the accessible name
  # of the stop, which is the thing this feature has to get right anyway.
  def stop(reel, number) = find("[aria-label='Reel #{reel} stop #{number}']")
  def column(position) = find("[data-reel-position-value='#{position}']")
  def values(position) = column(position).all("[data-reel-target='rows'] input").map(&:value)
  def focused = page.evaluate_script("document.activeElement.getAttribute('aria-label')")

  test "counts the stops and symbols as a reel is typed" do
    stop(3, 1).set("A")
    stop(3, 1).send_keys(:enter)
    stop(3, 2).set("K")
    stop(3, 2).send_keys(:enter)
    stop(3, 3).set("K")

    within(column(3)) { assert_text "3 stops" }

    # A column, most frequent first, with the counts aligned under one another: the
    # tally is read by comparing numbers down it.
    assert_equal [ "K  2", "A  1" ], column(3).find("[data-reel-target='counts']").text.split("\n")
  end

  # Typing straight down a column without reaching for the mouse is the point.
  test "enter moves down the column, adding a stop at the bottom" do
    assert_equal 1, values(4).length, "reel 4 has no strip, so it starts with one empty stop"

    stop(4, 1).send_keys("A", :enter)
    assert_equal "Reel 4 stop 2", focused

    page.driver.browser.action.send_keys("K").send_keys(:enter).perform
    assert_equal "Reel 4 stop 3", focused
    assert_equal %w[ A K ], values(4).first(2)
  end

  test "enter moves down an existing reel without adding to it" do
    stop(1, 1).send_keys(:enter)

    assert_equal "Reel 1 stop 2", focused
    assert_equal 6, values(1).length
  end

  test "backspace on an empty stop removes it" do
    stop(1, 3).send_keys([ :control, "a" ], :backspace, :backspace)

    # The stops below move up, and the numbering is renumbered to match.
    assert_equal %w[ A K K Q Q ], values(1)
    assert_equal "Reel 1 stop 2", focused
  end

  # The control appears on the row being worked on, so getting to it means being on
  # that row — which is how anybody would meet it.
  test "a stop can be removed with its own control" do
    stop(1, 1).click
    find("[aria-label='Remove reel 1 stop 1']").click

    assert_equal %w[ K Q K Q Q ], values(1)
  end

  # How strips actually arrive: a column copied out of a spreadsheet.
  test "pasting a column fills downwards, adding stops as needed" do
    paste_into stop(2, 1), "A\nK\nQ\nJ\nA\nK"

    assert_equal %w[ A K Q J A K ], values(2)
    within(column(2)) { assert_text "6 stops" }
  end

  test "a pasted column shorter than the reel leaves the rest alone" do
    paste_into stop(1, 1), "J\nJ"

    assert_equal %w[ J J Q K Q Q ], values(1)
  end

  test "a stop can be added with the button" do
    column(1).find("[data-add-stop]").click

    assert_equal 7, values(1).length
    assert_equal "Reel 1 stop 7", focused
  end

  test "saves every reel together" do
    stop(4, 1).set("A")
    stop(5, 1).set("Q")

    click_on "Save reels"

    assert_text "Reels saved"
    assert_equal %w[ A ], @variation.reel_strips.find_by(position: 4).symbols
    assert_equal %w[ Q ], @variation.reel_strips.find_by(position: 5).symbols
  end

  test "an unknown code is reported against its reel and the typing is kept" do
    stop(2, 1).set("ZZ")

    click_on "Save reels"

    assert_text "ZZ is not a symbol in this game"
    # A rejected save must not throw away what was typed.
    assert_equal "ZZ", stop(2, 1).value
  end


  # Tuning a strip is mostly inserting, not appending: a stop added at 14 pushes
  # everything below it down.
  test "shift-enter inserts a stop above the one you are on" do
    stop(1, 3).send_keys([ :shift, :enter ])

    assert_equal "Reel 1 stop 3", focused, "the new stop takes the number it was inserted at"
    assert_equal [ "A", "K", "", "Q", "K", "Q", "Q" ], values(1)

    page.driver.browser.action.send_keys("J").perform
    assert_equal %w[ A K J Q K Q Q ], values(1)
  end

  test "a stop can be inserted with its own control" do
    stop(1, 1).click
    find("[aria-label='Insert a stop above reel 1 stop 1']").click

    # Above, so a stop can be put before the first one — which appending cannot do.
    assert_equal [ "", "A", "K", "Q", "K", "Q", "Q" ], values(1)
    assert_equal "Reel 1 stop 1", focused
  end

  test "an inserted stop is saved in its place" do
    stop(1, 3).send_keys([ :shift, :enter ])
    page.driver.browser.action.send_keys("J").perform

    click_on "Save reels"

    assert_text "Reels saved"
    assert_equal %w[ A K J Q K Q Q ], @variation.reel_strips.find_by(position: 1).symbols
  end

  private
    # ClipboardEvent cannot be produced by sending keys, so the event is dispatched
    # directly with the data a real paste would carry.
    def paste_into(input, text)
      page.execute_script(<<~JS, input, text)
        const [ input, text ] = arguments
        const data = new DataTransfer()
        data.setData("text", text)
        input.dispatchEvent(new ClipboardEvent("paste", { clipboardData: data, bubbles: true, cancelable: true }))
      JS
    end
end
