# Putting a variation back to a configuration it held earlier.
#
# Shown before it happens rather than behind a confirm dialog: what will be put back,
# what will not, and whether the figure will land where it did. A restore that quietly
# produced a different number than the one clicked would be worse than no restore.
class RestorationsController < ApplicationController
  before_action :load_restore

  def new
  end

  def create
    return render :new, status: :unprocessable_entity unless @restore.possible?

    @restore.call

    # Restoring is a change like any other, so it is worked out and recorded like one.
    # That is what leaves the configuration being left behind still in the history.
    Calculation.start(@variation)

    redirect_to [ @game, @variation ], notice: "Restored the configuration from #{@figure.created_at.strftime("%d %b %H:%M")}."
  end

  private
    # Scoped through the owner, and the figure through the variation, so neither
    # another person's variation nor another variation's figure is reachable.
    def load_restore
      @variation = Current.user.games.find(params[:game_id]).variations.find(params[:variation_id])
      @game = @variation.game
      @figure = @variation.rtp_figures.find(params[:figure_id])
      @restore = ConfigurationRestore.new(@figure)
    end
end
