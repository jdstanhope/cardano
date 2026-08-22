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

  test "reserves a header slot for auth actions without linking to pages that do not exist" do
    get root_url

    assert_select "[data-account-actions]", 1,
      "the header should reserve a slot for sign in and register"
    assert_select "[data-account-actions] a", 0,
      "the reserved slot must stay empty until those pages exist"
  end

  test "shows the reel window with its winning combination" do
    get root_url

    assert_select "[data-reel-window]", 1
    assert_select "[data-reel-window] [data-winning]", 3,
      "the leading run of three matching symbols forms the winning combination"
  end
end
