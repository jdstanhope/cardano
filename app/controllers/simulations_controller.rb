# Asking for a return to be sampled rather than evaluated.
#
# Everything on offer here is a choice from a list. The ceiling in particular is the only
# thing bounding how long a run holds a worker, and a number field is an invitation to
# type a trillion into it — so a request naming anything not on offer is not an error to
# report but a request nobody could have made through the page, and it gets the least
# work of the set.
class SimulationsController < ApplicationController
  before_action :load_variation

  def create
    missing = @variation.missing_for_rtp
    return redirect_back_with(alert: "Nothing to sample yet: #{missing.to_sentence}.") if missing.any?

    if @variation.calculations.in_flight.any?
      redirect_back_with notice: "Already working that out."
    else
      Calculation.simulate(@variation, precision: precision, seed: seed)
      redirect_back_with notice: "Sampling."
    end
  end

  private
    def precision
      Rtp::Precision.new(points: chosen(Rtp::Precision::POINTS, :points),
                         confidence: chosen(Rtp::Precision::CONFIDENCES, :confidence),
                         ceiling: chosen(Rtp::Precision::CEILINGS, :ceiling))
    end

    def chosen(offered, key)
      offered.find { |candidate| candidate.to_s == params[key].to_s } || Rtp::Precision::DEFAULTS.fetch(key)
    end

    # Blank for a new one. A seed from a recorded run reproduces it exactly, which is what
    # the field is for; anything else is ignored rather than refused, because the person
    # pasting a seed in is investigating a figure, not filling in a form.
    def seed
      given = params[:seed].to_s.strip
      return unless given.match?(/\A\d+\z/)

      given.to_i.then { |value| value if value < Calculation::SEEDS }
    end

    # Scoped through the owner, so another person's variation is a 404.
    def load_variation
      @variation = Current.user.games.find(params[:game_id]).variations.find(params[:variation_id])
      @game = @variation.game
    end

    def redirect_back_with(**flash) = redirect_to([ @game, @variation ], **flash)
end
