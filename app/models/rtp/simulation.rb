class Rtp
  # A return estimated by playing the game rather than reasoning about it.
  #
  # Exact evaluation factorises the outcome space, which works while the space
  # factorises. Sampling does not care: it draws a stop per reel, reads what the paytable
  # says, and averages. That buys the figures expectation cannot reach, and costs the
  # certainty — so the answer arrives with an interval attached and never without one.
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
      @variation = variation
      @seed = seed
      @confidence = confidence
    end

    attr_reader :seed, :confidence

    def run(spins:)
      table = SpinTable.for(variation)
      rng = Random.new(seed)

      total = 0
      mean = 0.0
      squares = 0.0

      spins.times do |played|
        payout = table.spin(rng)
        total += payout

        # Welford: the mean is corrected as it goes and the squared distance is
        # accumulated against both the old mean and the new, which is what keeps it
        # stable over hundreds of millions of spins where the naive form drifts.
        difference = payout - mean
        mean += difference / (played + 1)
        squares += difference * (payout - mean)
      end

      Result.new(value: Rational(total, spins * table.stake_units), method: SAMPLED,
                 interval: interval_for(squares, spins, table.stake_units))
    end

    private
      attr_reader :variation

      # The standard error of the mean payout, carried into the units the figure is in.
      #
      # A single spin has no spread to measure and nothing truthful to say about its own
      # accuracy, so it says so rather than reporting a confident nothing.
      def interval_for(squares, spins, stake_units)
        return Interval.for(standard_error: Float::INFINITY, confidence: confidence) if spins < 2

        variance = squares / (spins - 1)

        Interval.for(standard_error: Math.sqrt(variance / spins) / stake_units, confidence: confidence)
      end
  end
end
