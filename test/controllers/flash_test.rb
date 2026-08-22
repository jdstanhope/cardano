require "test_helper"

class FlashTest < ActionDispatch::IntegrationTest
  test "a notice is shown on the page it redirects to, not carried on to the next one" do
    post registration_url, params: {
      user: {
        email_address: "designer@example.com",
        password: "a-long-enough-password",
        password_confirmation: "a-long-enough-password"
      }
    }

    follow_redirect!
    assert_select "#notice", /account is ready/i

    get new_session_url
    assert_select "#notice", 0, "the notice should not survive to a later page"
  end
end
