# Editing a combination of any shape: a sequence of positions, each naming one symbol
# or one group.
#
# The grid on the same page edits the one shape it can express — the same symbol
# repeated — and is quicker for it. This handles everything, including the shapes the
# grid has no cell for.
class PaytableCombinationsController < ApplicationController
  before_action :load_variation

  def create
    entry = @variation.paytable_entries.new

    write(entry) { redirect_back_with notice: "Added #{describe(entry)}.#{moved(entry)}" }
  end

  def update
    entry = @variation.paytable_entries.find(params[:id])

    write(entry) { redirect_back_with notice: "Saved #{describe(entry)}.#{moved(entry)}" }
  end

  def destroy
    entry = @variation.paytable_entries.find(params[:id])
    described = describe(entry)
    entry.destroy!

    redirect_back_with notice: "Removed #{described}."
  end

  private
    # Scoped through the owner, so another person's variation is a 404.
    def load_variation
      @variation = Current.user.games.find(params[:game_id]).variations.find(params[:variation_id])
      @game = @variation.game
    end

    def write(entry)
      sequence = submitted_sequence
      return redirect_back_with(alert: sequence) if sequence.is_a?(String)

      PaytableEntry.transaction do
        entry.matchers.destroy_all
        entry.payout = params[:payout]
        sequence.each_with_index { |named, index| entry.matchers.build(position: index + 1, **position_for(named)) }
        entry.save!
      end

      yield
    rescue ActiveRecord::RecordInvalid => e
      redirect_back_with alert: e.record.errors.full_messages.to_sentence
    end

    def position_for(named) = named.is_a?(SymbolGroup) ? { symbol_group: named } : { game_symbol: named }

    # Returns the sequence, or a message explaining why it is not one. A gap is
    # rejected rather than closed up: "R7, nothing, W7" almost certainly means a
    # half-finished edit, and silently reading it as a two-symbol combination would
    # save something nobody described.
    def submitted_sequence
      tokens = Array(params[:sequence]).first(@game.reel_count.to_i).map(&:to_s)
      filled = tokens.map(&:presence)

      return "A combination cannot have a gap. Fill the positions from the left." if filled.compact != filled.take_while(&:itself)

      named = filled.compact.map { |token| resolve(token) }

      return "That combination names something that is not in this game." if named.any?(&:nil?)

      named
    end

    # Scoped to the game, so a symbol from somebody else's game reads as absent rather
    # than being loaded and then refused.
    def resolve(token)
      kind, id = token.split(":", 2)

      case kind
      when "symbol" then @game.symbols.find_by(id: id)
      when "group" then @game.symbol_groups.find_by(id: id)
      end
    end

    def describe(entry) = entry.sequence.join(" ")

    # The same symbol in every position is edited in the grid, so a row that becomes one
    # leaves this list. Said out loud, because a row disappearing on save otherwise
    # reads as having lost the edit.
    def moved(entry) = entry.n_of_a_kind? ? " The same symbol repeated is edited in the grid above." : ""

    def redirect_back_with(**flash) = redirect_to([ @game, @variation ], **flash)
end
