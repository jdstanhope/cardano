# The exact return to player of a variation.
#
# Computed by expectation rather than by walking the outcome space. Reels stop
# independently, which is what makes that possible and exact — see Rtp::Lines and
# Rtp::Ways for how each mechanic uses it.
#
# Arithmetic is rational throughout. Probabilities are fractions with known
# denominators, so nothing is approximated until a percentage is rendered for display.
# Evaluating exactly and then rounding through floating point would give up the thing
# the exactness was for.
class Rtp
  # How a figure was arrived at, recorded so a simulated figure can never be mistaken for
  # an exact one. Exact evaluation reasons about probabilities; sampling plays the game
  # and counts. Both produce a return, and only one of them is the return.
  EXACT = :exact
  SAMPLED = :sampled

  # How far a sampled figure might be from the truth, and how sure that claim is.
  #
  # Floating point deliberately. The figure itself is a count over a count and stays
  # exactly rational; this is an estimate of an estimate, and giving it the same
  # arithmetic would dress a guess up as a measurement.
  Interval = Struct.new(:half_width, :confidence, keyword_init: true) do
    # Standard normal deviates for the confidences the tool offers. A table rather than an
    # inverse normal function, because three values is the whole requirement and a general
    # one would be more code doing less that can be checked by eye.
    DEVIATES = { 90 => 1.645, 95 => 1.960, 99 => 2.576 }.freeze

    def self.for(standard_error:, confidence:)
      new(half_width: DEVIATES.fetch(confidence) * standard_error, confidence: confidence)
    end

    # In percentage points, which is the unit a target band is argued in.
    def points = half_width * 100

    def to_s = format("±%.2f points at %d%%", points, confidence)
  end

  Result = Struct.new(:value, :method, :interval, keyword_init: true) do
    def exact? = method == EXACT

    # As a percentage, rounded only here.
    def to_percentage(places = 2) = format("%.#{places}f%%", value * 100)

    def basis_points = (value * 10_000).round

    # Whether the figure lands inside a variation's target band, or nil when it has
    # none to be measured against.
    #
    # Judged on the range the figure might be in rather than on the figure itself. For an
    # exact figure those are the same thing and this answers exactly as it always did.
    # For a sampled one they are not: an interval reaching past an edge means the run has
    # not distinguished the two sides yet, and saying "below band" on the strength of
    # where the midpoint fell would report a property of the sample as a property of the
    # game — which is the whole thing carrying an interval is meant to prevent.
    def against(minimum, maximum)
      return if minimum.nil? || maximum.nil?

      low, high = bounds
      return :unsettled if low.nil?
      return :below if high < minimum
      return :above if low > maximum
      return :inside if low >= minimum && high <= maximum

      :unsettled
    end

    # The range the figure might actually be in, in basis points. A run too short to have
    # measured any spread says its interval is infinite, and there is no range to give.
    def bounds
      return [ basis_points, basis_points ] if interval.nil?
      return unless interval.half_width.finite?

      margin = (interval.half_width * 10_000).round

      [ basis_points - margin, basis_points + margin ]
    end
  end

  Incomplete = Struct.new(:reasons, keyword_init: true) do
    def complete? = false
    def to_s = reasons.to_sentence
  end

  def initialize(variation)
    @variation = variation
    @game = variation.game
  end

  def call
    missing = missing_pieces
    return Incomplete.new(reasons: missing) if missing.any?

    Result.new(value: expected_payout / stake, method: EXACT)
  end

  # What the description is missing, if anything. A figure computed from an incomplete
  # description would look like an answer while being meaningless, so say what is
  # missing instead.
  #
  # Cheap — it counts records rather than evaluating anything — so it can also be asked
  # before deciding whether a run is worth starting at all.
  def missing_pieces
    [].tap do |missing|
      missing << "no reel strips" if variation.reel_strips.empty?
      missing << "#{game.reel_count - variation.reel_strips.size} reels have no strip" if variation.reel_strips.any? && variation.reel_strips.size < game.reel_count
      missing << "no paytable combinations" if variation.paytable_entries.empty?
      missing << "no paylines" if game.pays_by_lines? && game.paylines.empty?
    end
  end

  private
    attr_reader :variation, :game

    def mechanic = @mechanic ||= WinMechanic.for(game)

    def stake = mechanic.stake_units

    def expected_payout
      case game.win_mechanic
      when "ways" then Ways.new(variation).expected_payout
      else Lines.new(variation).expected_payout
      end
    end
end
