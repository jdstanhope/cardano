class Rtp
  # How accurate a figure has to be before the run producing it can stop.
  #
  # Nobody wants a spin count. What somebody wants is a figure accurate enough to take to
  # an operator, and how many spins that takes depends on the game's volatility — which is
  # arithmetic the tool can do as it goes and the person cannot do at all.
  #
  # Reaching the ceiling short of the precision is a result rather than a failure. It is
  # also the ordinary outcome for a tight request: Red White & Blue is still at +/-3.2
  # points after 300,000 spins, because one combination in it pays 2400 and dominates the
  # spread. A run that says "+/-0.11 after five billion spins" has answered the question
  # asked of it, which was how accurate the figure could be made.
  class Precision
    # Below this, precision cannot end a run. An interval taken from a handful of spins
    # can be narrow by luck rather than by evidence, and a rule that believed it would
    # stop almost every run immediately.
    FLOOR = 100_000

    # How often the rule is consulted. A square root per spin would cost more than the
    # spin does, and this also bounds how far past the requested precision a run can
    # overshoot before it notices.
    BATCH = 50_000

    # What the interface offers. Held here rather than in the controller because these
    # are the three things a precision is made of, and a list of them belongs with it.
    #
    # The defaults are not simply the first of each: the confidence is the conventional
    # one rather than the least demanding, and the ceiling is enough to settle an ordinary
    # game at the default precision without holding a worker for hours. Red White & Blue
    # reaches ±0.5 points in twelve and a half million spins and would want over a billion
    # for ±0.05, so the loose end is where a first attempt belongs.
    POINTS = [ 0.5, 0.25, 0.1, 0.05 ].freeze
    CONFIDENCES = [ 90, 95, 99 ].freeze
    CEILINGS = [ 10_000_000, 100_000_000, 1_000_000_000, 5_000_000_000 ].freeze
    DEFAULTS = { points: 0.5, confidence: 95, ceiling: 100_000_000 }.freeze

    attr_reader :points, :confidence, :ceiling

    def initialize(points:, confidence:, ceiling:)
      @points = points
      @confidence = confidence
      @ceiling = ceiling
    end

    # Never past the ceiling, so a run ends on the number it was given rather than on
    # whatever the last whole batch happened to reach.
    def batch(spins) = [ BATCH, ceiling - spins ].min

    # Why the run should stop, or nil while it should not.
    #
    # Precision is asked first. A run that reaches its accuracy on the same batch that
    # reaches its ceiling has answered the question, and reporting the limit instead of
    # the result would describe how it ran rather than what it found.
    def reached(spins:, interval:)
      return :precision if spins >= FLOOR && interval.points <= points
      return :ceiling if spins >= ceiling

      nil
    end
  end
end
