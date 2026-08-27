module WinMechanic
  # One entry per payline that produces a win, each occurring once.
  #
  # A line pays its best interpretation, and only that one. Three red sevens satisfy
  # "3 red 7s", "any 3 sevens" and "any 3 reds" at once, and a spin that pays all three
  # would be counted three times. Taking the best-paying match is the whole rule, and
  # it is also what makes a longer combination supersede a shorter one without needing
  # a rule about lengths.
  class Lines < Base
    def stake_units = game.paylines.size

    def wins(window, entries)
      game.paylines.filter_map do |payline|
        best_win_for(payline.rows.each_with_index.map { |row, reel| window.at(reel, row) }, entries)
      end
    end

    # The win a sequence of symbols produces, one per reel, or nil. Public because the
    # RTP calculation reasons about lines as symbol sequences: it never spins, so it
    # has no window to hand over.
    def best_win_for(symbols_on_line, entries)
      matching = entries.select { |entry| entry.matches?(symbols_on_line) }

      matching.max_by(&:payout)&.then { |entry| Win.new(entry: entry, times: 1) }
    end
  end
end
