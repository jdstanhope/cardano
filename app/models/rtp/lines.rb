class Rtp
  # Expected payout of a lines game, per unit of line stake.
  #
  # For a fixed row, the symbol on a reel is distributed as that strip's frequency: a
  # reel stops uniformly, and shifting by a row only relabels which stop is landed on.
  # Every payline therefore sees the same marginal distribution, so one line's
  # expectation multiplied by the number of lines is the whole answer.
  #
  # The sum runs over symbol combinations rather than stop combinations. A ten symbol
  # five reel game has 100,000 of the former and tens of millions of the latter, and
  # only the symbols determine what a line pays.
  #
  # Summing each symbol's run independently would be quicker and wrong: a line pays its
  # best reading once, and W W A A A and W W K K K are one outcome read two ways.
  # Evaluating whole combinations is what keeps that rule intact.
  class Lines
    def initialize(variation)
      @variation = variation
      @game = variation.game
    end

    def expected_payout
      mechanic = WinMechanic.for(game)
      paytable = variation.paytable_lookup

      per_line = combinations.sum do |combination, probability|
        win = mechanic.best_win_for(combination, paytable)
        win ? probability * win.payout(paytable) : 0
      end

      per_line * game.paylines.size
    end

    private
      attr_reader :variation, :game

      # Every symbol combination across the reels, with its probability.
      def combinations
        distributions.reduce([ [ [], Rational(1) ] ]) do |partial, reel|
          partial.flat_map do |symbols, probability|
            reel.map { |symbol, chance| [ symbols + [ symbol ], probability * chance ] }
          end
        end
      end

      # Per reel: how likely each symbol is to land on a given row.
      def distributions
        variation.reel_strips.sort_by(&:position).map do |strip|
          length = strip.symbols.length

          strip.symbols.tally.filter_map do |code, count|
            symbol = game.symbols.find { |candidate| candidate.code == code }
            [ symbol, Rational(count, length) ] if symbol
          end
        end
      end
  end
end
