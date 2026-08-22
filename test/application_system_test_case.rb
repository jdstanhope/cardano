require "test_helper"
require "socket"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
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
end
