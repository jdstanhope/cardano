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

  # How many seeds there are to invent from. Large enough that two runs colliding is not
  # a thing to think about, small enough to be a bigint.
  SEEDS = 1 << 48

  def self.start(variation, computed_by: Rtp::EXACT)
    begin_run(variation, computed_by: computed_by)
  end

  # A run that samples to the precision asked for, rather than evaluating.
  #
  # The seed is recorded, and invented when not given. A figure somebody disputes is the
  # case this exists to serve, and one that cannot be recomputed to the same number
  # cannot be looked into at all — so the seed is never left to chance twice.
  def self.simulate(variation, precision:, seed: nil)
    begin_run(variation,
              computed_by: Rtp::SAMPLED,
              seed: seed || SecureRandom.random_number(SEEDS),
              precision_points: (precision.points * 100).round,
              confidence: precision.confidence,
              ceiling: precision.ceiling)
  end

  def self.begin_run(variation, **attributes)
    create!(variation: variation, state: QUEUED, fingerprint: RtpFingerprint.for(variation), **attributes)
      .tap { |calculation| RtpCalculationJob.perform_later(calculation) }
  end
  private_class_method :begin_run

  def in_flight? = IN_FLIGHT.include?(state)
  def sampled? = computed_by == Rtp::SAMPLED.to_s
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
    sampled? ? by_sampling : by_evaluation
  rescue StandardError => e
    finish(FAILED, failure: "#{e.class}: #{e.message}".truncate(200))
  end

  private
    def by_evaluation
      result = variation.rtp

      if result.respond_to?(:exact?)
        finish(DONE, rtp_figure: RtpFigure.record(variation, result))
      else
        finish(FAILED, failure: result.to_s)
      end
    end

    # Asked before compiling anything. A description missing a reel would blow up inside
    # the compiler, and that is a result to show rather than a stack trace to catch.
    def by_sampling
      missing = Rtp.new(variation).missing_pieces
      return finish(FAILED, failure: missing.to_sentence) if missing.any?

      simulation = Rtp::Simulation.new(variation, seed: seed)
      result = simulation.run_to(precision, interrupted: method(:cancelled_elsewhere?))

      self.spins = simulation.spins
      self.stopped_because = simulation.stopped_because

      # A stopped run keeps what it found. Usually it was stopped for taking too long,
      # and the figure so far is the thing that was wanted — nothing is overstated by
      # keeping it, because the interval is wide and the coverage thin and the page shows
      # both. This is where sampling legitimately differs from evaluation: an exact run
      # cancelled part way has no partial answer, and a sampled one does.
      finish(simulation.stopped_because == :cancelled ? CANCELLED : DONE,
             rtp_figure: RtpFigure.record(variation, result,
                                          spins: simulation.spins, coverage: simulation.coverage))
    end

    # Whether somebody has stopped this run since it started, which only the database
    # knows — the person who pressed the button was in another process.
    #
    # Read past the query cache. A job runs inside one, so a repeated read of this row is
    # answered from memory: the run would see the state it began with for the rest of its
    # life, never notice the cancellation, and leave nothing in the log to say why.
    def cancelled_elsewhere?
      self.class.uncached { self.class.where(id: id).pick(:state) == CANCELLED }
    end

    # Stored in basis points, the unit a target band already uses.
    def precision
      Rtp::Precision.new(points: precision_points / 100.0, confidence: confidence, ceiling: ceiling)
    end
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
