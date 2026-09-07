class Rtp
  # A return estimated by playing the game rather than reasoning about it.
  #
  # Exact evaluation factorises the outcome space, which works while the space
  # factorises. Sampling does not care: it draws a stop per reel, reads what the paytable
  # says, and averages. That buys the figures expectation cannot reach, and costs the
  # certainty — so the answer arrives with an interval attached and never without one.
  #
  # A run rather than a calculation. It carries its own progress, so it can be played in
  # batches and asked where it stands between them, which is what letting the precision
  # decide when to stop requires.
  #
  # Two kinds of arithmetic, deliberately.
  #
  # The **figure** stays exact. Payouts are whole numbers and spins are counted, so the
  # estimate is a whole payout over a whole count and Rational carries it without losing
  # anything. It is an estimate of the return, but it is exactly the average of what was
  # played, and it drops into RtpFigure's numerator and denominator unchanged.
  #
  # The **variance** is floating point, by Welford's running mean. Summing squares of
  # payouts would be exact and would leave fixnum range partway through a real run,
  # putting bignum arithmetic in the hottest loop in the application to size a number
  # that only ever describes uncertainty.
  class Simulation
    DEFAULT_CONFIDENCE = 95

    def initialize(variation, seed:, confidence: DEFAULT_CONFIDENCE)
      @seed = seed
      @confidence = confidence
      @table = SpinTable.for(variation)
      @rng = Random.new(seed)
      @spins = 0
      @total = 0
      @mean = 0.0
      @squares = 0.0
    end

    attr_reader :seed, :confidence, :spins, :stopped_because

    # How often each combination actually landed. Reported beside the interval rather
    # than allowed to block a run: refusing to stop until every combination had been seen
    # would run every simulation of a game with a rare one to its ceiling, and make the
    # requested precision decorative. Saying what was seen leaves the judgement where it
    # belongs.
    def coverage = @table.coverage

    # Plays a fixed number of spins and reports where the estimate stands.
    def run(spins:)
      play(spins)

      result
    end

    # Plays until the precision says to stop, or until whatever is watching says to.
    #
    # Both reasons are weighed in one place, before each batch, and precision is weighed
    # first: a run that reached the accuracy it was asked for on the same batch somebody
    # stopped it has finished, and reporting the interruption would describe how it ended
    # rather than what it achieved. Asking after playing instead would silently reverse
    # that, because the interruption would be seen a batch before the precision it
    # coincided with.
    #
    # Nothing can interrupt a run that has not played yet, so a stopped run always has a
    # figure to show for itself.
    #
    # `interrupted` is anything that answers `call`, deliberately — a run should not have
    # to know that the thing watching it is a database row.
    def run_to(precision, interrupted: nil)
      loop do
        @stopped_because = precision.reached(spins: spins, interval: interval(precision.confidence))
        @stopped_because ||= :cancelled if spins.positive? && interrupted&.call
        break if stopped_because

        play(precision.batch(spins))
      end

      result(precision.confidence)
    end

    private
      def play(count)
        count.times do
          payout = @table.spin(@rng)
          @total += payout
          @spins += 1

          # Welford: the mean is corrected as it goes and the squared distance is
          # accumulated against both the old mean and the new, which is what keeps it
          # stable over hundreds of millions of spins where the naive form drifts.
          difference = payout - @mean
          @mean += difference / @spins
          @squares += difference * (payout - @mean)
        end
      end

      def result(at = confidence)
        Result.new(value: Rational(@total, spins * @table.stake_units), method: SAMPLED, interval: interval(at))
      end

      # The standard error of the mean payout, carried into the units the figure is in.
      #
      # Too few spins have no spread to measure and nothing truthful to say about their
      # own accuracy, so they say so rather than reporting a confident nothing.
      def interval(at = confidence)
        return Interval.for(standard_error: Float::INFINITY, confidence: at) if spins < 2

        variance = @squares / (spins - 1)

        Interval.for(standard_error: Math.sqrt(variance / spins) / @table.stake_units, confidence: at)
      end
  end
end
