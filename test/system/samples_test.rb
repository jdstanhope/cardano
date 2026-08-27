require "application_system_test_case"

class SamplesTest < ApplicationSystemTestCase
  setup { sign_in_through_the_form(users(:one)) }

  # Both buttons submit a form rather than following a link, which is exactly the kind
  # of thing an integration test can assert about and only a browser can prove.
  test "a sample can be copied, and the copy duplicated again" do
    visit games_path

    click_on "Copy to my games"

    assert_text "is yours to change"
    # The heading rather than the text: the sample's own name is on the list page too.
    assert_selector "h1", text: "Red White & Blue"

    click_on "Duplicate"

    assert_text "leave the original alone"
    assert_selector "h1", text: "Red White & Blue (copy)"

    visit games_path
    assert_text "Red White & Blue"
    assert_text "Red White & Blue (copy)"
  end
end
