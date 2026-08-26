class SymbolGroupsController < ApplicationController
  before_action :set_game

  def create
    group = @game.symbol_groups.new(group_params)
    group.position ||= (@game.symbol_groups.maximum(:position) || 0) + 1

    if group.save
      redirect_to @game, notice: "Added the #{group.name} group."
    else
      redirect_to @game, alert: group.errors.full_messages.to_sentence
    end
  end

  def update
    group = @game.symbol_groups.find(params[:id])

    if group.update(group_params)
      redirect_to @game, notice: "#{group.name} updated."
    else
      redirect_to @game, alert: group.errors.full_messages.to_sentence
    end
  end

  def destroy
    group = @game.symbol_groups.find(params[:id])
    group.destroy

    redirect_to @game, notice: "Removed the #{group.name} group."
  end

  private
    def set_game
      @game = Current.user.games.find(params[:game_id])
    end

    def group_params
      params.expect(symbol_group: [ :name, { game_symbol_ids: [] } ])
    end
end
