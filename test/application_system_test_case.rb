require "test_helper"
require "socket"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Capybara waits 2 seconds by default. That is enough locally and not always enough
  # on a cold CI runner, where the first Turbo form submission has to warm up: a run
  # failed there while passing here, and passed on re-run without any change. Waiting
  # longer does not prove a race is gone, it just stops a slow machine reading as a
  # failure — assertions still return as soon as the page settles.
  Capybara.default_max_wait_time = 5

  if ENV["SELENIUM_REMOTE_URL"].present?
    # The browser runs in its own container, so it cannot reach the test server on
    # localhost. Bind to every interface and hand the browser this container's
    # address on the compose network. The port is pinned so it is predictable.
    #
    # An IP rather than the `app` hostname on purpose: Chrome upgrades http to https
    # for named hosts, and the test server is plain http, so a hostname produces
    # ERR_SSL_PROTOCOL_ERROR before the request ever reaches Puma. IP literals are
    # not upgraded.
    container_ip = Socket.ip_address_list.find { |a| a.ipv4? && !a.ipv4_loopback? }.ip_address

    Capybara.server_host = "0.0.0.0"
    Capybara.server_port = 3001
    Capybara.app_host = "http://#{container_ip}:3001"

    browser_options = Selenium::WebDriver::Chrome::Options.new.tap do |options|
      options.add_argument("--no-sandbox")
      options.add_argument("--disable-dev-shm-usage")
    end

    # Not headless: the selenium image runs a real display, so a run can be watched
    # at http://localhost:7900 while it happens.
    driven_by :selenium, using: :chrome, screen_size: [ 1400, 1400 ], options: {
      browser: :remote,
      url: ENV["SELENIUM_REMOTE_URL"],
      options: browser_options
    }
  else
    # GitHub Actions provides its own Chrome, and so does a native checkout.
    driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]
  end

  # Fills a field and confirms it kept the value, re-entering it once if it did not.
  #
  # A late DOM replacement can land after a field has been filled and discard what was
  # typed. Three CI runs failed that way, and a fourth failed here with the value
  # already confirmed empty, so waiting longer does not recover it — the value is gone
  # rather than late, and it has to be entered again.
  #
  # This has never reproduced locally. The retry is deliberately once: if a second
  # attempt is also wiped, something is wrong that a test should not paper over.
  def fill_in_and_confirm(locator, with:)
    fill_in locator, with: with

    begin
      assert_field locator, with: with
    rescue Minitest::Assertion
      fill_in locator, with: with
      assert_field locator, with: with
    end
  end

  # SessionTestHelper#sign_in_as sets a cookie directly, which only integration tests
  # can do. A system test has to go through the form like anyone else.
  def sign_in_through_the_form(user, password: "password")
    visit new_session_path

    within "form" do
      fill_in "Email address", with: user.email_address
      fill_in "Password", with: password
      click_on "Sign in"
    end

    # Wait for the dashboard to actually render, not just for the URL to change.
    # assert_current_path is satisfied as soon as Turbo updates the address, which can
    # be before the body has been replaced — and a body swap landing after the next
    # page is being typed into wipes what was typed, so the form then submits the old
    # value and the page looks untouched. That was the shape of two flaky CI failures.
    assert_selector "h1", text: "Games"
  end
end
