class Rtp
  # Expected payout of a ways game, per unit of way stake.
  #
  # Every symbol pays independently in a ways game, so there is no best-interpretation
  # coupling and each symbol can be taken on its own. Within a symbol, the reels are
  # independent, so the expectation factorises across them.
  #
  # For a run of exactly L reels paying at length P:
  #
  #   E[payout] = pay(P) x (product of E[matches] for the first P reels)
  #                      x (product of P(match) for reels P+1..L)
  #                      x P(no match on reel L+1)
  #
  # The first product carries the arrangements, since the ways are counted over the
  # reels forming the combination being paid. The second covers reels that extend the
  # run past what the paytable prices, which still have to match for the run to reach
  # that far. The last closes the run.
  class Ways
    def initialize(variation)
      @variation = variation
      @game = variation.game
    end

    def expected_payout
      paytable = variation.paytable_lookup

      game.symbols.reject(&:wild?).sum { |symbol| expected_for(symbol, paytable) }
    end

    private
      attr_reader :variation, :game

      def expected_for(symbol, paytable)
        stats = reel_statistics(symbol)

        (1..stats.length).sum do |run|
          paying = WinMechanic.paying_length(symbol, run, paytable)
          next 0 if paying.nil?

          pay = paytable.dig(symbol, paying) || 0
          next 0 if pay.zero?

          arrangements = stats.first(paying).map { |reel| reel[:expected] }.reduce(:*)
          extending = stats[paying...run].map { |reel| reel[:any] }.reduce(1, :*)
          closes = stats[run] ? stats[run][:none] : Rational(1)

          pay * arrangements * extending * closes
        end
      end

      # Per reel: how many positions match on average, how likely at least one does,
      # and how likely none does. Taken over the stop positions a reel can rest at.
      def reel_statistics(symbol)
        variation.reel_strips.sort_by(&:position).map do |strip|
          windows = stop_windows(strip)
          counts = windows.map { |window| window.count { |shown| matches?(shown, symbol) } }
          total = counts.length

          {
            expected: Rational(counts.sum, total),
            any: Rational(counts.count(&:positive?), total),
            none: Rational(counts.count(&:zero?), total)
          }
        end
      end

      # The rows a reel shows for each position it can stop at, wrapping around.
      def stop_windows(strip)
        codes = strip.symbols
        codes.length.times.map do |stop|
          game.row_count.times.map { |offset| codes[(stop + offset) % codes.length] }
        end
      end

      def matches?(code, symbol)
        shown = game.symbols.find { |candidate| candidate.code == code }
        return false if shown.nil?

        shown == symbol || (shown.wild? && shown.substitutes_for?(symbol))
      end
  end
end
