class PaytablesController < ApplicationController
  def update
    @variation = Current.user.games.find(params[:game_id]).variations.find(params[:variation_id])
    @game = @variation.game
    @paytable = PaytableForm.new(variation: @variation, payouts: submitted_payouts)
    @form = ReelStripsForm.new(variation: @variation)
    @rtp = @variation.rtp

    if @paytable.save
      redirect_to [ @game, @variation ], notice: "Paytable saved."
    else
      render "variations/show", status: :unprocessable_entity
    end
  end

  private
    # Filtered structurally here — numeric keys, and only counts this window can show.
    # Whether a symbol belongs to this game is a domain rule, so PaytableForm decides
    # it and says so; filtering it out here instead would make that rule unreachable.
    def submitted_payouts
      reachable = @game.payable_counts.to_set

      params.fetch(:payouts, {}).to_unsafe_h.each_with_object({}) do |(symbol_id, cells), filtered|
        next unless symbol_id.to_s.match?(/\A\d+\z/)

        filtered[symbol_id] = (cells || {}).select { |count, _| reachable.include?(count.to_i) }
      end
    end
end
