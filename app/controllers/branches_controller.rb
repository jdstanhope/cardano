# A new variation holding what this one holds now.
#
# Variations exist to carry alternative reel strips and paytables for one game, so
# trying something is copying a configuration into a fresh one rather than editing the
# one that works.
class BranchesController < ApplicationController
  def create
    variation = Current.user.games.find(params[:game_id]).variations.find(params[:variation_id])
    branch = VariationBranch.from_variation(variation)

    return redirect_to([ variation.game, variation ], alert: branch.refusals.to_sentence.upcase_first + ".") unless branch.possible?

    created = branch.call
    Calculation.start(created)

    redirect_to [ created.game, created ],
      notice: "Variation #{created.label} holds what #{variation.label} holds. Changes here leave #{variation.label} alone."
  end
end
