class GamesController < ApplicationController
  # Current.user.games is the only entry point. Game.find must not appear here:
  # scoping every lookup through the owner is what makes another person's game
  # a 404 rather than a 403, and a 403 would confirm the record exists.
  def index
    @games = games.order(:name)
  end

  def new
    @game = games.new(reel_count: 5, row_count: 3)
  end

  def create
    @game = games.new(game_params)

    if @game.save
      redirect_to @game, notice: "#{@game.name} is ready to describe."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @game = games.find(params[:id])
  end

  private
    def games
      Current.user.games
    end

    def game_params
      params.expect(game: [ :name, :reel_count, :row_count ])
    end
end
