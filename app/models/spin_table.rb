# A variation compiled into something a spin can be evaluated against quickly.
#
# Exact evaluation reasons about probabilities and never spins. Simulation has to spin,
# hundreds of millions of times, and reaching through ActiveRecord objects to do it
# manages a few hundred spins a second — not enough for the method to be worth having.
#
# So the variation is compiled once. Symbols become integer indices, paytable entries
# become bits, and a spin becomes table lookups and integer arithmetic that never touches
# a symbol object. The tables are built by asking PaytableMatcher#matches?, so the
# matching rules are not restated here — what is stored is their precomputed answers.
# Wilds, exclusions and groups therefore cannot drift between this and exact evaluation,
# because there is still only one definition of them.
#
# What is written twice is how a mechanic assembles wins, and SpinTableTest holds this to
# WinMechanic across every one of Red White & Blue's 262,144 outcomes.
class SpinTable
  def self.for(variation)
    case variation.game.win_mechanic
    when "ways" then raise NotImplementedError, "ways games cannot be compiled yet"
    else Lines.new(variation)
    end
  end

  def initialize(variation)
    @variation = variation
    @game = variation.game
    compile
  end

  # How many units a spin costs, which is what a return is taken over.
  attr_reader :stake_units

  # The stops each reel can come to rest on, which is what a spin draws from.
  attr_reader :stop_counts

  def spin(rng) = payout_at(stop_counts.map { |count| rng.rand(count) })

  private
    attr_reader :variation, :game

    # The symbol index a reel shows at a row, having stopped where it did. A reel
    # stopping at s shows s, s+1, ... wrapping around, which is the convention
    # Rtp::Ways#stop_windows already reads strips by.
    def symbol_at(reel, stop, offset)
      strip = @strips[reel]
      strip[(stop + offset) % strip.length]
    end
end
