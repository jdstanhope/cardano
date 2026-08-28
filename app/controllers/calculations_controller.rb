class CalculationsController < ApplicationController
  before_action :load_variation

  def create
    missing = @variation.missing_for_rtp
    return redirect_back_with(alert: "Nothing to work out yet: #{missing.to_sentence}.") if missing.any?

    if @variation.calculations.in_flight.any?
      redirect_back_with notice: "Already working that out."
    else
      Calculation.start(@variation)
      redirect_back_with notice: "Working it out."
    end
  end

  def destroy
    calculation = @variation.calculations.find(params[:id])
    calculation.cancel! if calculation.in_flight?

    redirect_back_with notice: "Stopped."
  end

  private
    # Scoped through the owner, so another person's variation is a 404.
    def load_variation
      @variation = Current.user.games.find(params[:game_id]).variations.find(params[:variation_id])
      @game = @variation.game
    end

    def redirect_back_with(**flash) = redirect_to([ @game, @variation ], **flash)
end
