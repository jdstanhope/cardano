module WinMechanic
  # One entry per symbol, occurring as many times as the arrangements allow.
  #
  # Ways cannot enumerate its combinations one by one and does not need to: a 5x3
  # window has 243 of them and a 6x4 has 4,096, but there are only ever as many entries
  # as there are symbols. The count is the product of the matching positions on each
  # reel, up to where the run stops.
  #
  # Unlike a payline, every winning symbol pays. There is no single line to choose a
  # best interpretation on, so A x3 and K x3 can both land on one spin and both count.
  class Ways < Base
    # One unit per way, and the ways are the product of the rows on each reel.
    def stake_units = game.reel_count.times.reduce(1) { |total, _| total * game.row_count }

    def wins(window, paytable)
      payable_symbols.filter_map do |symbol|
        matches = (0...game.reel_count).map { |reel| window.matches_on(reel, symbol) }
        run = run_length_for(symbol, matches)
        next if run.zero?

        # The arrangements are counted over the reels that form the combination being
        # paid, which is not always the whole run.
        paying = WinMechanic.paying_length(symbol, run, paytable)
        next if paying.nil?

        win = Win.new(symbol: symbol, length: paying, times: matches.take(paying).reduce(:*))

        win if win.payout(paytable).positive?
      end
    end
  end
end
