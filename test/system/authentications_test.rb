require "application_system_test_case"

class AuthenticationsTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
  end

  test "signing in and back out" do
    visit root_path
    click_on "Sign in"

    within "form" do
      fill_in "Email address", with: @user.email_address
      fill_in "Password", with: "password"
      click_on "Sign in"
    end

    assert_current_path root_path
    assert_link "Sign out"

    # Sign out is a link carrying data-turbo-method, so this only works if Turbo is
    # loaded and issues the DELETE. No integration test can cover that.
    click_on "Sign out"

    assert_current_path new_session_path
    assert_link "Sign in"
    assert_no_link "Sign out"
  end

  test "registering from the sign in page" do
    visit new_session_path
    click_on "Create an account"

    within "form" do
      fill_in "Email address", with: "designer@example.com"
      fill_in "Password", with: "a-long-enough-password"
      fill_in "Confirm password", with: "a-long-enough-password"
      click_on "Create account"
    end

    assert_current_path root_path
    assert_text "Your account is ready"
    assert_link "Sign out"
  end

  test "registration reports why it was rejected" do
    visit new_registration_path

    within "form" do
      fill_in "Email address", with: @user.email_address
      fill_in "Password", with: "a-long-enough-password"
      fill_in "Confirm password", with: "a-long-enough-password"
      click_on "Create account"
    end

    assert_text(/already been taken/i)
    assert_no_link "Sign out"
  end
end
