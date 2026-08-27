# A game somebody can copy into their account rather than describing by hand.
#
# Defined in code rather than owned by an account, so nobody can edit the canonical
# one, and so the sample is the same data the RTP calculation is verified against.
# A sample that is provably correct is worth more than one that merely looks plausible.
class SampleGame
  def self.all = [ RedWhiteAndBlue ]

  def self.find(key) = all.find { |sample| sample.key == key }

  class << self
    def key = name.demodulize.underscore
  end

  # Builds the game into an account. Everything is created through the models, so a
  # sample that would not survive validation cannot be planted.
  def self.build_for(user, name: nil)
    definition = self::DEFINITION

    Game.transaction do
      attributes = definition.fetch(:game)
      game = user.games.create!(attributes.merge(name: name || GameName.free_for(user, attributes.fetch(:name))))

      symbols = definition.fetch(:symbols).each_with_index.to_h do |(code, name), index|
        [ code, game.symbols.create!(code: code, name: name, position: index + 1) ]
      end

      groups = definition.fetch(:groups, {}).each_with_index.to_h do |(group_name, members), index|
        group = game.symbol_groups.create!(name: group_name, position: index + 1)
        group.game_symbols << members.map { |code| symbols.fetch(code) }
        [ group_name, group ]
      end

      definition.fetch(:paylines, []).each_with_index do |rows, index|
        game.paylines.create!(position: index + 1, rows: rows)
      end

      variation = game.variations.first
      variation.update!(definition.fetch(:variation, {}))

      definition.fetch(:strips).each_with_index do |codes, index|
        variation.reel_strips.create!(position: index + 1, symbols: codes)
      end

      definition.fetch(:pays).each do |payout, sequence|
        entry = variation.paytable_entries.new(payout: payout)
        sequence.each_with_index do |thing, index|
          named = symbols[thing] || groups.fetch(thing)
          key = named.is_a?(SymbolGroup) ? :symbol_group : :game_symbol
          entry.matchers.build(position: index + 1, key => named)
        end
        entry.save!
      end

      game
    end
  end
end
