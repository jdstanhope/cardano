class SamplesController < ApplicationController
  def create
    sample = SampleGame.find(params[:key])
    return redirect_to games_path, alert: "That sample is not one we have." if sample.nil?

    game = sample.build_for(Current.user)

    redirect_to game, notice: "#{sample.title} is yours to change."
  end
end
