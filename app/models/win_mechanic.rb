# How a game selects the combinations it offers to the paytable.
#
# Both mechanics answer the same question and differ only in how. Given the window a
# spin produced, each yields the winning shapes as
#
#   symbol, run length, how many times it occurs
#
# Lines yields one entry per payline that produces a run, each occurring once. Ways
# yields one entry per symbol, occurring as many times as the arrangements allow.
#
# The multiplicity is what lets one interface serve both. Lines is always one, which is
# exactly what it is rather than a special case.
#
# A mechanic also answers what a spin costs, because RTP is return over stake and the
# stake is not the same: a lines game bets one unit per payline, a ways game one unit
# per way. Evaluation cannot compute a figure without asking.
module WinMechanic
  NAMES = %w[ lines ways ].freeze

  Win = Struct.new(:symbol, :length, :times, keyword_init: true) do
    def payout(paytable) = (paytable.dig(symbol, length) || 0) * times
  end

  # The combination a run of this length actually pays: the longest count the paytable
  # defines that the run reaches. Five of a kind on a paytable that only names three
  # pays the three, rather than paying nothing because five was never priced.
  def self.paying_length(symbol, run_length, paytable)
    (paytable[symbol] || {}).keys.select { |count| count <= run_length }.max
  end

  def self.for(game)
    case game.win_mechanic
    when "ways" then Ways.new(game)
    else Lines.new(game)
    end
  end

  # Shared by both: how far a run of one symbol reaches from the leftmost reel, given
  # what each reel offers. A wild counts toward a symbol it substitutes for, which is
  # why this asks the symbol rather than comparing identity.
  class Base
    def initialize(game)
      @game = game
    end

    attr_reader :game

    private
      def run_length_for(symbol, matches_per_reel)
        matches_per_reel.take_while(&:positive?).length.then do |reached|
          reached.zero? ? 0 : reached
        end
      end

      def substitutes?(candidate, symbol)
        candidate == symbol || (candidate&.wild? && candidate.substitutes_for?(symbol))
      end

      def payable_symbols = game.symbols.reject(&:wild?)
  end
end
