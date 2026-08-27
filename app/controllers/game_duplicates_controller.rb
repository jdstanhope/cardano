class GameDuplicatesController < ApplicationController
  # Scoped to Current.user.games, so duplicating somebody else's game is a 404 rather
  # than a copy. Without the scope this would be a way to read any game in the system
  # by taking a copy of it.
  def create
    source = Current.user.games.find(params[:game_id])
    copy = GameDuplication.call(source, owner: Current.user)

    redirect_to copy, notice: "Copied #{source.name}. Changes here leave the original alone."
  end
end
