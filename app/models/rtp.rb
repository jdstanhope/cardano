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
  # How a figure was arrived at. Only one method exists today; it is recorded from the
  # start so a simulated figure can never be mistaken for an exact one when Monte Carlo
  # arrives for games too large or too dynamic to evaluate.
  EXACT = :exact

  Result = Struct.new(:value, :method, keyword_init: true) do
    def exact? = method == EXACT

    # As a percentage, rounded only here.
    def to_percentage(places = 2) = format("%.#{places}f%%", value * 100)

    def basis_points = (value * 10_000).round

    # Whether the figure lands inside a variation's target band, or nil when it has
    # none to be measured against.
    def against(minimum, maximum)
      return if minimum.nil? || maximum.nil?

      points = basis_points
      return :below if points < minimum
      return :above if points > maximum

      :inside
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

    # A figure computed from an incomplete description would look like an answer while
    # being meaningless, so say what is missing instead.
    def missing_pieces
      [].tap do |missing|
        missing << "no reel strips" if variation.reel_strips.empty?
        missing << "#{game.reel_count - variation.reel_strips.size} reels have no strip" if variation.reel_strips.any? && variation.reel_strips.size < game.reel_count
        missing << "no paytable combinations" if variation.paytable_entries.empty?
        missing << "no paylines" if game.pays_by_lines? && game.paylines.empty?
      end
    end
end
