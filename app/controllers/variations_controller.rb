class VariationsController < ApplicationController
  def show
    @variation = variation
    @game = @variation.game
    @form = ReelStripsForm.new(variation: @variation)
    @paytable = PaytableForm.new(variation: @variation)
    @rtp = @variation.record_rtp
  end

  def create
    game = Current.user.games.find(params[:game_id])
    number = game.next_variation_number

    if number.nil?
      redirect_to game, alert: "#{game.name} already has all #{Variation::NUMBERS.count} variations."
    else
      variation = game.variations.create!(number: number)
      redirect_to [ game, variation ], notice: "Variation #{variation.label} added."
    end
  end

  private
    # Scoped through the owner, so another person's variation is a 404.
    def variation
      Current.user.games.find(params[:game_id]).variations.find(params[:id])
    end
end
