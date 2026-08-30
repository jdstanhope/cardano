# A new variation holding a configuration this one had earlier.
#
# The same operation as BranchesController with a configuration from the history rather
# than the current one, which is what makes a checkpoint something to keep as well as
# something to go back to.
class FigureBranchesController < ApplicationController
  def create
    variation = Current.user.games.find(params[:game_id]).variations.find(params[:variation_id])
    figure = variation.rtp_figures.find(params[:figure_id])
    branch = VariationBranch.from_figure(figure)

    return redirect_to([ variation.game, variation ], alert: branch.refusals.to_sentence.upcase_first + ".") unless branch.possible?

    created = branch.call
    Calculation.start(created)

    redirect_to [ created.game, created ],
      notice: "Variation #{created.label} holds the configuration from #{figure.created_at.strftime("%d %b %H:%M")}. #{variation.label} is unchanged."
  end
end
