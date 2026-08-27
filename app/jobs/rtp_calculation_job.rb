class RtpCalculationJob < ApplicationJob
  queue_as :default

  # Calculation#perform never raises, so a retry would repeat work that already
  # recorded its outcome. A run that failed is a result to look at.
  discard_on StandardError

  def perform(calculation) = calculation.perform
end
