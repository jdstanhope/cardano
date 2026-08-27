# How a game selects the combinations it offers to the paytable.
#
# Both mechanics answer the same question and differ only in how. Given the window a
# spin produced, each yields the winning shapes as
#
#   the combination, and how many times it occurs
#
# Lines yields one entry per payline that produces a win, each occurring once. Ways
# yields one per combination, occurring as many times as the arrangements allow.
#
# The multiplicity is what lets one interface serve both. Lines is always one, which is
# exactly what it is rather than a special case.
#
# A mechanic also answers what a spin costs, because RTP is return over stake and the
# stake is not the same: a lines game bets one unit per payline, a ways game one unit
# per way. Evaluation cannot compute a figure without asking.
module WinMechanic
  NAMES = %w[ lines ways ].freeze

  Win = Struct.new(:entry, :times, keyword_init: true) do
    def payout = entry.payout * times
    def symbol = entry.matchers.first&.game_symbol
    def length = entry.length
  end

  def self.for(game)
    case game.win_mechanic
    when "ways" then Ways.new(game)
    else Lines.new(game)
    end
  end

  class Base
    def initialize(game)
      @game = game
    end

    attr_reader :game
  end
end
