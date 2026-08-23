module WinMechanic
  # One entry per payline that produces a run, each occurring once.
  #
  # A line pays its best interpretation, and only that one. Several readings of one
  # line may win — W W A A A and W W K K K are the same outcome read two ways — and
  # paying both would count the same spin twice.
  class Lines < Base
    def stake_units = game.paylines.size

    def wins(window, paytable)
      game.paylines.filter_map { |payline| best_win_on(payline, window, paytable) }
    end

    private
      def best_win_on(payline, window, paytable)
        symbols_on_line = payline.rows.each_with_index.map { |row, reel| window.at(reel, row) }

        candidates = payable_symbols.filter_map do |symbol|
          matches = symbols_on_line.map { |shown| substitutes?(shown, symbol) ? 1 : 0 }
          run = run_length_for(symbol, matches)
          next if run.zero?

          paying = WinMechanic.paying_length(symbol, run, paytable)
          Win.new(symbol: symbol, length: paying, times: 1) if paying
        end

        candidates.max_by { |win| win.payout(paytable) }.then { |best| best if best&.payout(paytable)&.positive? }
      end
  end
end
