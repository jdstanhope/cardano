class VariationsController < ApplicationController
  def show
    @variation = variation
    @game = @variation.game
    @form = ReelStripsForm.new(variation: @variation)
    @paytable = PaytableForm.new(variation: @variation)
  end

  private
    # Scoped through the owner, so another person's variation is a 404.
    def variation
      Current.user.games.find(params[:game_id]).variations.find(params[:id])
    end
end
