class PaylinesController < ApplicationController
  before_action :set_game

  # Its own page: a twenty-five line set is twenty-five drawn shapes and a picker of
  # ninety-nine more, which is more than a column of the game page can carry.
  def index
    # A ways game has no paylines to edit, so there is nothing here to show it.
    redirect_to @game if @game.pays_by_ways?
  end

  # Adds one line, leaving the rest alone. The shape comes from the catalogue rather
  # than being typed: a mistyped payline is still a valid payline, so it produces a
  # plausible RTP instead of an error.
  def create
    rows = Array(params[:rows]).map(&:to_i)

    if @game.paylines.any? { |payline| payline.rows == rows }
      redirect_to game_paylines_path(@game), alert: "That line is already in this game."
      return
    end

    payline = @game.paylines.new(position: next_position, rows: rows)

    if payline.save
      redirect_to game_paylines_path(@game), notice: "Added payline #{payline.position}."
    else
      redirect_to game_paylines_path(@game), alert: payline.errors.full_messages.to_sentence
    end
  end

  # Applying a set replaces the game's paylines rather than adding to them. A set is
  # a starting point, and merging two sets would produce duplicates that are valid
  # individually and wrong together.
  def apply_set
    set = PaylineCatalogue.new(@game).sets.find { |candidate| candidate.size == params[:size].to_i }

    if set.nil?
      redirect_to game_paylines_path(@game), alert: "That set is not available for a #{@game.reel_count}x#{@game.row_count} window."
      return
    end

    @game.transaction do
      @game.paylines.destroy_all
      set.rows.each_with_index { |rows, index| @game.paylines.create!(position: index + 1, rows: rows) }
    end

    redirect_to game_paylines_path(@game), notice: "Applied the #{set.label} set."
  end

  def destroy
    payline = @game.paylines.find(params[:id])
    payline.destroy

    redirect_to game_paylines_path(@game), notice: "Payline #{payline.position} removed."
  end

  private
    def next_position
      (@game.paylines.maximum(:position) || 0) + 1
    end

    def set_game
      @game = Current.user.games.find(params[:game_id])
    end
end
