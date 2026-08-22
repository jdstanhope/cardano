require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "renders the registration page" do
    get new_registration_url

    assert_response :success
    assert_select "h1", /create an account/i
  end

  test "offers a way back to signing in" do
    get new_registration_url

    assert_select "a[href=?]", new_session_path
  end

  test "creates an account and signs the person in" do
    assert_difference -> { User.count }, 1 do
      post registration_url, params: {
        user: {
          email_address: "designer@example.com",
          password: "a-long-enough-password",
          password_confirmation: "a-long-enough-password"
        }
      }
    end

    assert_redirected_to games_url, "a new account should land where it can make a game"
    assert_equal "designer@example.com", User.last.email_address

    follow_redirect!
    assert_select "[data-account-actions] a[href=?]", session_path
  end

  test "rejects a password confirmation that does not match" do
    assert_no_difference -> { User.count } do
      post registration_url, params: {
        user: {
          email_address: "designer@example.com",
          password: "a-long-enough-password",
          password_confirmation: "something-else"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "[data-form-errors]", /confirmation/i
  end

  test "rejects an email address that is already registered" do
    assert_no_difference -> { User.count } do
      post registration_url, params: {
        user: {
          email_address: users(:one).email_address,
          password: "a-long-enough-password",
          password_confirmation: "a-long-enough-password"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "[data-form-errors]", /already/i
  end

  test "treats email addresses case insensitively when detecting duplicates" do
    assert_no_difference -> { User.count } do
      post registration_url, params: {
        user: {
          email_address: users(:one).email_address.upcase,
          password: "a-long-enough-password",
          password_confirmation: "a-long-enough-password"
        }
      }
    end

    assert_response :unprocessable_entity
  end
end
