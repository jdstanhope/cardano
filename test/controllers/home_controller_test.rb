require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "root renders the home page" do
    get root_url

    assert_response :success
  end

  test "says what the tool is" do
    get root_url

    assert_select "h1", /maths/i
  end

  test "names the four figures it reports" do
    get root_url

    [ "RTP", "Hit frequency", "Volatility", "Max win" ].each do |figure|
      assert_select "dt", text: figure
    end
  end

  test "is reachable without signing in" do
    get root_url

    assert_response :success
  end

  test "offers sign in and register to a signed-out visitor" do
    get root_url

    assert_select "[data-account-actions] a[href=?]", new_session_path
    assert_select "[data-account-actions] a[href=?]", new_registration_path
  end

  test "offers sign out to a signed-in visitor, and not sign in" do
    sign_in_as users(:one)

    get root_url

    assert_select "[data-account-actions] a[href=?]", session_path
    assert_select "[data-account-actions] a[href=?]", new_session_path, 0,
      "someone already signed in should not be offered sign in"
  end

  test "shows the reel window with its winning combination" do
    get root_url

    assert_select "[data-reel-window]", 1
    assert_select "[data-reel-window] [data-winning]", 3,
      "the leading run of three matching symbols forms the winning combination"
  end
end
