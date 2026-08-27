module WinMechanic
  # One entry per winning combination, occurring as many times as the arrangements
  # allow: the product of the matching positions on each reel it covers.
  #
  # Ways cannot enumerate its combinations one by one and does not need to — a 5x3
  # window has 243 of them and a 6x4 has 4,096, but there are only ever as many entries
  # as the paytable has.
  #
  # Unlike a payline, several combinations pay at once: A x3 and K x3 can both land on
  # one spin and both count. But not every match may pay, or one outcome gets counted
  # twice — four of a kind also matches the three of a kind entry. Only the best-paying
  # match for each starting matcher counts, which for N-of-a-kind is one per symbol.
  class Ways < Base
    def stake_units = game.reel_count.times.reduce(1) { |total, _| total * game.row_count }

    def wins(window, entries)
      candidates = entries.filter_map do |entry|
        times = arrangements(entry, window)
        Win.new(entry: entry, times: times) if times.positive?
      end

      candidates.group_by { |win| win.entry.matchers.first&.label }.values.map { |group| group.max_by(&:payout) }
    end

    private
      # Zero unless every reel the combination covers offers at least one match.
      def arrangements(entry, window)
        entry.matchers.each_with_index.reduce(1) do |total, (matcher, reel)|
          count = window.matches_for(reel, matcher)
          return 0 if count.zero?

          total * count
        end
      end
  end
end
