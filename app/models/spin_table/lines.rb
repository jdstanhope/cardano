class SpinTable
  # A lines game compiled to bitsets.
  #
  # Each paytable entry is one bit, ordered by descending payout. For a reel and a symbol,
  # the mask holds the entries whose matcher at that reel accepts it — plus every entry
  # too short to reach the reel, since nothing there can disqualify them. A payline is
  # then the intersection across its reels.
  #
  # Because the bits run in payout order, the best-paying match is the lowest set bit,
  # which is `live & -live`. That is the "a line pays its best reading once" rule
  # WinMechanic::Lines states, arrived at without comparing anything: no scan over the
  # matching entries, no max_by.
  #
  # The masks are held per stop rather than per symbol, so a spin never looks a symbol up
  # or takes a modulo — what a reel shows is a function of where it stopped, and that is
  # settled once here instead of every spin. Measured at 200,738 spins a second against
  # 141,376 for building the window each time, on a 5x3 game with 20 paylines. The cost is
  # one integer per reel, stop and row: a few hundred for an ordinary game.
  #
  # One entry is one bit, so the whole set is a single machine word while a variation has
  # at most 62 combinations. Past that Ruby's integers leave fixnum range and every
  # intersection allocates, which measures at about half the rate. The design document
  # records the remedy; it is not worth building until a paytable that large exists.
  class Lines < SpinTable
    # Every bit set. Used as the identity for `&` rather than a mask of the right width,
    # which for a large paytable would be the one bignum the loop can avoid.
    EVERYTHING = -1

    def payout_at(stops)
      @lines.sum do |line|
        live = EVERYTHING

        line.each do |reel, offset|
          live &= @mask_at[reel][stops[reel]][offset]
          break if live.zero?
        end

        live.zero? ? 0 : @payout_for[live & -live]
      end
    end

    private
      def compile
        symbols = game.symbols.to_a
        entries = variation.paytable.sort_by { |entry| -entry.payout }
        index = symbols.each_with_index.to_h { |symbol, position| [ symbol.code, position ] }

        @payout_for = entries.each_with_index.to_h { |entry, position| [ 1 << position, entry.payout ] }
        @strips = variation.reel_strips.sort_by(&:position).map { |strip| strip.symbols.map { |code| index[code] } }
        @stop_counts = @strips.map(&:length)
        @stake_units = WinMechanic.for(game).stake_units

        accepted = game.reel_count.times.map { |reel| symbols.map { |shown| accepted_by(entries, reel, shown) } }
        @mask_at = game.reel_count.times.map do |reel|
          @stop_counts[reel].times.map do |stop|
            game.row_count.times.map { |offset| accepted[reel][symbol_at(reel, stop, offset)] }
          end
        end

        # A payline names a row per reel, counted from the centre; strips are read from
        # the top. Converting once here keeps the offset out of the spin.
        @lines = game.paylines.map do |payline|
          payline.rows.each_with_index.map { |row, reel| [ reel, game.offset_from_top(row) ] }
        end
      end

      # The entries still able to pay when this symbol lands on this reel.
      def accepted_by(entries, reel, shown)
        entries.each_with_index.reduce(0) do |bits, (entry, position)|
          matcher = entry.matchers[reel]

          matcher.nil? || matcher.matches?(shown) ? bits | (1 << position) : bits
        end
      end
  end
end
