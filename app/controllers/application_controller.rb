class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private
    # The generator falls back to root_url, which is the marketing page. A deep link
    # stored before signing in still takes precedence over this.
    def after_authentication_url
      super_url = session.delete(:return_to_after_authenticating)
      super_url || games_url
    end
end
