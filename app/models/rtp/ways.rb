class Rtp
  # Expected payout of a ways game, per unit of way stake.
  #
  # Combinations pay independently, so each can be taken on its own, and within one the
  # reels are independent, so the expectation factorises across them. A combination's
  # payout is its value times the arrangements — the product of matching positions on
  # each reel it covers — so its expectation is the value times the product of the
  # expected matches per reel.
  #
  # Only the best match per opening matcher pays, or an outcome is counted twice: four
  # of a kind also matches the three of a kind combination. A shorter combination
  # therefore pays only when the longer one does not reach, which is the probability
  # that the next reel offers no match at all.
  #
  # That reasoning assumes the combinations in a family are prefixes of one another,
  # which is what N-of-a-kind paytables are. Anything else is checked against brute
  # force rather than assumed — see the tests.
  class Ways
    def initialize(variation)
      @variation = variation
      @game = variation.game
      @expected = {}
    end

    def expected_payout
      variation.paytable.group_by { |entry| entry.matchers.first&.label }.sum do |_opening, family|
        expected_for_family(family)
      end
    end

    private
      attr_reader :variation, :game

      def expected_for_family(family)
        ordered = family.sort_by(&:length)

        ordered.each_with_index.sum do |entry, index|
          longer = ordered[(index + 1)..].max_by(&:length)

          entry.payout * arrangements(entry) * unreached(longer, entry.length)
        end
      end

      # Expected arrangements of a combination: the product across the reels it covers.
      # Zero-match reels contribute zero, which removes the outcomes it does not win.
      def arrangements(entry)
        entry.matchers.each_with_index.reduce(Rational(1)) do |total, (matcher, reel)|
          total * expected_matches(reel, matcher)
        end
      end

      # The chance the next longer combination in the family fails to reach, which is
      # the chance its first extra reel offers nothing. One when there is no longer
      # combination, since nothing can supersede it.
      def unreached(longer, length)
        return Rational(1) if longer.nil?

        no_match(length, longer.matchers[length])
      end

      def expected_matches(reel, matcher)
        statistics(reel, matcher)[:expected]
      end

      def no_match(reel, matcher)
        return Rational(1) if matcher.nil?

        statistics(reel, matcher)[:none]
      end

      def statistics(reel, matcher)
        @expected[[ reel, matcher.id ]] ||= begin
          windows = stop_windows(reel)
          counts = windows.map { |window| window.count { |shown| matcher.matches?(shown) } }

          { expected: Rational(counts.sum, counts.length), none: Rational(counts.count(&:zero?), counts.length) }
        end
      end

      # The rows a reel shows for each position it can stop at, wrapping around.
      def stop_windows(reel)
        @windows ||= {}
        @windows[reel] ||= begin
          strip = variation.reel_strips.find { |candidate| candidate.position == reel + 1 }
          by_code = game.symbols.index_by(&:code)
          codes = strip.symbols

          codes.length.times.map do |stop|
            game.row_count.times.map { |offset| by_code[codes[(stop + offset) % codes.length]] }
          end
        end
      end
  end
end
