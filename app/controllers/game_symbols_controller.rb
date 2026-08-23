class GameSymbolsController < ApplicationController
  before_action :set_game

  def create
    @symbol = @game.symbols.new(symbol_params)
    @symbol.position ||= (@game.symbols.maximum(:position) || 0) + 1

    if @symbol.save
      redirect_to @game, notice: "#{@symbol.display_name} added."
    else
      # The form lives on the game's page, so failures are shown there rather than
      # on a page of their own.
      @game = @game.reload
      render "games/show", status: :unprocessable_entity
    end
  end

  def update
    symbol = @game.symbols.find(params[:id])

    if symbol.update(symbol_params)
      redirect_to @game, notice: "#{symbol.display_name} updated."
    else
      redirect_to @game, alert: symbol.errors.full_messages.to_sentence
    end
  end

  def destroy
    symbol = @game.symbols.find(params[:id])

    if symbol.destroy
      redirect_to @game, notice: "#{symbol.display_name} removed."
    else
      redirect_to @game, alert: symbol.errors[:base].to_sentence
    end
  end

  private
    # Scoped through the owner, so another person's game is a 404 here too.
    def set_game
      @game = Current.user.games.find(params[:game_id])
    end

    def symbol_params
      params.expect(game_symbol: [ :code, :name, :wild ])
    end
end
