require "application_system_test_case"

class GamesTest < ApplicationSystemTestCase
  test "signing in lands on the dashboard, where a game can be created" do
    visit new_session_path

    within "form" do
      fill_in "Email address", with: users(:one).email_address
      fill_in "Password", with: "password"
      click_on "Sign in"
    end

    # Signing in should land on the dashboard, not the marketing page.
    assert_current_path games_path

    click_on "New game"
    assert_selector "h1", text: "New game"

    within "form" do
      fill_in_and_confirm "Name", with: "Midnight Reels"
      fill_in_and_confirm "Reels", with: "5"
      fill_in_and_confirm "Rows", with: "3"

      click_on "Create game"
    end

    assert_text "Midnight Reels"

    visit games_path
    assert_text "Midnight Reels"
  end
end
