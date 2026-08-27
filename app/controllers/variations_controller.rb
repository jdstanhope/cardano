class VariationsController < ApplicationController
  def show
    @variation = variation
    @game = @variation.game
    @form = ReelStripsForm.new(variation: @variation)
    @paytable = PaytableForm.new(variation: @variation)
    # Exact evaluation of an ordinary five reel game takes tens of seconds, so the page
    # asks for the figure rather than waiting for it. What it shows meanwhile is the
    # last figure it has, marked as describing an earlier description.
    Calculation.start(@variation) if @variation.calculation_wanted?
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
