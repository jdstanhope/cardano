# One attempt at working out what a variation returns.
#
# A run rather than a figure: it has a lifecycle, it can be watched while it happens,
# and it can fail or be cancelled without producing anything. Exact evaluation of an
# ordinary five reel game takes tens of seconds and a simulation takes minutes, so this
# is what the page shows instead of blocking on a number that is not ready.
#
# Deliberately a first-class record rather than a spinner. Searching for a variation
# that meets a set of requirements is many of these at once, and that search should be
# able to enumerate runs rather than have them invented again.
class Calculation < ApplicationRecord
  QUEUED = "queued"
  RUNNING = "running"
  DONE = "done"
  FAILED = "failed"
  CANCELLED = "cancelled"

  STATES = [ QUEUED, RUNNING, DONE, FAILED, CANCELLED ].freeze
  IN_FLIGHT = [ QUEUED, RUNNING ].freeze

  belongs_to :variation
  belongs_to :rtp_figure, optional: true

  validates :state, inclusion: { in: STATES }
  validates :computed_by, :fingerprint, presence: true

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }
  scope :in_flight, -> { where(state: IN_FLIGHT) }

  after_commit :show_the_change

  def self.start(variation, computed_by: Rtp::EXACT)
    create!(variation: variation, computed_by: computed_by, state: QUEUED,
            fingerprint: RtpFingerprint.for(variation))
      .tap { |calculation| RtpCalculationJob.perform_later(calculation) }
  end

  def in_flight? = IN_FLIGHT.include?(state)
  def done? = state == DONE
  def failed? = state == FAILED
  def cancelled? = state == CANCELLED

  def running! = update!(state: RUNNING, started_at: Time.current)

  def cancel! = finish(CANCELLED)

  # A figure produced for a description that has since changed is not wrong, but it is
  # not current either. Recording which it is here means the page never has to guess.
  def describes_the_variation_now? = fingerprint == RtpFingerprint.for(variation)

  def elapsed
    return if started_at.nil?

    ((finished_at || Time.current) - started_at).round
  end

  # Runs the calculation, whatever the outcome. Never raises: a run that blew up is a
  # result to show, not a job to retry forever.
  def perform
    return if cancelled?

    running!
    result = variation.rtp

    if result.respond_to?(:exact?)
      finish(DONE, rtp_figure: RtpFigure.record(variation, result))
    else
      finish(FAILED, failure: result.to_s)
    end
  rescue StandardError => e
    finish(FAILED, failure: "#{e.class}: #{e.message}".truncate(200))
  end

  private
    def finish(state, rtp_figure: nil, failure: nil)
      update!(state: state, finished_at: Time.current, rtp_figure: rtp_figure, failure: failure)
    end

    # The page is watching. Broadcasting on commit rather than on each state change
    # keeps a rolled back run from ever appearing.
    def show_the_change
      broadcast_replace_to variation, target: "return_to_player",
        partial: "variations/return_to_player", locals: { variation: variation }
    end
end
