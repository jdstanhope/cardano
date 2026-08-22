require "test_helper"

class SessionsLinksTest < ActionDispatch::IntegrationTest
  test "the sign in page offers a way to register" do
    get new_session_url

    assert_response :success
    assert_select "a[href=?]", new_registration_path
  end
end
