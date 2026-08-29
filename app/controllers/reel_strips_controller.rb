class ReelStripsController < ApplicationController
  def update
    @variation = Current.user.games.find(params[:game_id]).variations.find(params[:variation_id])
    @game = @variation.game
    @form = ReelStripsForm.new(variation: @variation, reels: submitted_reels)
    @paytable = PaytableForm.new(variation: @variation)
    @rtp = @variation.rtp

    if @form.save
      redirect_to [ @game, @variation ], notice: "Reels saved."
    else
      render "variations/show", status: :unprocessable_entity
    end
  end

  private
    # Only the reels this game actually has. A request naming reel 99 on a five reel
    # game is ignored rather than creating a strip that could never be shown.
    #
    # Each reel arrives as an array, one value per stop. A bare string is still
    # accepted, so a whole strip pasted as one value works the way it always did.
    def submitted_reels
      permitted = (1..@game.reel_count).to_h { |position| [ position.to_s, [] ] }

      params.fetch(:reels, {}).permit(permitted, *permitted.keys)
    end
end
