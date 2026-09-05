class SpinTable
  # A ways game compiled to counts.
  #
  # Ways does not intersect. A combination pays as many times as the arrangements allow —
  # the product of the matching positions on each reel it covers — so what a spin needs
  # is counts rather than a set of survivors. The window a reel shows is still a pure
  # function of where it stopped, so those counts settle once, per reel, stop and matcher,
  # and a spin multiplies integers.
  #
  # Several combinations pay at once, but only the best per opening matcher, or four of a
  # kind is counted again as three of a kind.
  #
  # **Best means best paying, not longest.** This follows WinMechanic::Ways, which takes
  # the largest `payout * times` in each family. Rtp::Ways reasons differently — a shorter
  # combination pays only where the longer one fails to reach — which is sound for an
  # expectation over the whole space but is not the same selection on a single spin: a
  # shorter combination with more arrangements can out-pay a longer one. Following the
  # mechanic is what the agreement test checks, so it is the mechanic that is followed.
  class Ways < SpinTable
    Combination = Struct.new(:payout, :reels)

    def payout_at(stops)
      @families.sum do |family|
        family.reduce(0) do |best, combination|
          paid = combination.payout * arrangements(combination, stops)

          paid > best ? paid : best
        end
      end
    end

    private
      # Zero unless every reel the combination covers offers at least one match, which is
      # what removes the outcomes it does not win.
      def arrangements(combination, stops)
        combination.reels.reduce(1) do |ways, (reel, matcher)|
          count = @counts[reel][stops[reel]][matcher]
          return 0 if count.zero?

          ways * count
        end
      end

      def compile
        symbols = game.symbols.to_a
        entries = variation.paytable
        index = symbols.each_with_index.to_h { |symbol, position| [ symbol.code, position ] }

        # Every matcher gets a column of its own. A matcher belongs to one combination, so
        # naming the same symbol twice is two columns, which costs a little room and saves
        # having to reason about when two matchers are the same question.
        matchers = entries.flat_map(&:matchers)
        column = matchers.each_with_index.to_h { |matcher, position| [ matcher.id, position ] }

        @strips = variation.reel_strips.sort_by(&:position).map { |strip| strip.symbols.map { |code| index[code] } }
        @stop_counts = @strips.map(&:length)
        @stake_units = WinMechanic.for(game).stake_units

        @counts = game.reel_count.times.map do |reel|
          @stop_counts[reel].times.map do |stop|
            window = game.row_count.times.map { |offset| symbols[symbol_at(reel, stop, offset)] }

            matchers.map { |matcher| window.count { |shown| matcher.matches?(shown) } }
          end
        end

        @families = entries.group_by { |entry| entry.matchers.first&.label }.values.map do |family|
          family.map do |entry|
            reels = entry.matchers.each_with_index.map { |matcher, reel| [ reel, column[matcher.id] ] }

            Combination.new(entry.payout, reels)
          end
        end
      end
  end
end
