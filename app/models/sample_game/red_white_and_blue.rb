class SampleGame
  # A real three reel machine, published with its reel strips, its paytable and a
  # theoretical return of 86.58% for one coin.
  #
  # This definition is what the verification test builds and checks against that
  # published figure, so the sample somebody copies is the same data the calculation is
  # proven against.
  #
  # The source does not say which symbols count as red, white or blue. The classic
  # design colours the bars — one bar red, two bar white, three bar blue — which makes
  # "1 bar, 2 bar, 3 bar" a specific case of "any red, any white, any blue". Under any
  # other reading the total does not land on the published figure.
  #
  # https://wizardofodds.com/games/slots/appendix/6/
  class RedWhiteAndBlue < SampleGame
    PUBLISHED_RETURN = 0.8658
    COMBINATIONS = 262_144

    STRIP_COUNTS = {
      "R7" => [ 1, 3, 1 ],
      "W7" => [ 6, 1, 7 ],
      "B7" => [ 6, 7, 1 ],
      "3B" => [ 6, 7, 5 ],
      "2B" => [ 7, 6, 9 ],
      "1B" => [ 6, 8, 9 ],
      "--" => [ 32, 32, 32 ]
    }.freeze

    DEFINITION = {
      game: { name: "Red White & Blue", reel_count: 3, row_count: 1 },

      symbols: {
        "R7" => "Red 7", "W7" => "White 7", "B7" => "Blue 7",
        "3B" => "3 bar", "2B" => "2 bar", "1B" => "1 bar", "--" => "Blank"
      },

      groups: {
        "Sevens" => %w[ R7 W7 B7 ],
        "Bars" => %w[ 1B 2B 3B ],
        "Reds" => %w[ R7 1B ],
        "Whites" => %w[ W7 2B ],
        "Blues" => %w[ B7 3B ]
      },

      paylines: [ [ 0, 0, 0 ] ],

      variation: { target_rtp_min: 8600, target_rtp_max: 8700 },

      strips: 3.times.map { |reel| STRIP_COUNTS.flat_map { |code, counts| Array.new(counts[reel], code) } },

      # One coin, as published.
      pays: [
        [ 2400, %w[ R7 W7 B7 ] ],
        [ 1199, %w[ R7 R7 R7 ] ],
        [  200, %w[ W7 W7 W7 ] ],
        [  150, %w[ B7 B7 B7 ] ],
        [   80, %w[ Sevens Sevens Sevens ] ],
        [   50, %w[ 1B 2B 3B ] ],
        [   40, %w[ 3B 3B 3B ] ],
        [   25, %w[ 2B 2B 2B ] ],
        [   20, %w[ Reds Whites Blues ] ],
        [   10, %w[ 1B 1B 1B ] ],
        [    5, %w[ Bars Bars Bars ] ],
        [    2, %w[ Reds Reds Reds ] ],
        [    2, %w[ Whites Whites Whites ] ],
        [    2, %w[ Blues Blues Blues ] ],
        [    1, %w[ -- -- -- ] ]
      ].freeze
    }.freeze

    def self.title = DEFINITION.dig(:game, :name)

    def self.description
      "A real three reel machine, published as returning #{format("%.2f%%", PUBLISHED_RETURN * 100)}. " \
        "The calculation here is verified against that figure."
    end
  end
end
