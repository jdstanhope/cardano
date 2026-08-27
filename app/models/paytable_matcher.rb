# One position in a paytable combination: either a specific symbol or a group.
#
# A wild matches a group when it substitutes for at least one member. It stands in for
# some symbol, and if that symbol is in the group then the combination is satisfied.
class PaytableMatcher < ApplicationRecord
  belongs_to :paytable_entry
  belongs_to :game_symbol, optional: true
  belongs_to :symbol_group, optional: true

  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 }

  validate :names_exactly_one_thing
  validate :belongs_to_the_entry_s_game
  validate :does_not_name_the_wild

  def label = (game_symbol || symbol_group)&.then { |thing| game_symbol ? thing.code : thing.name }

  # Whether a symbol shown on a reel satisfies this position.
  def matches?(shown)
    return false if shown.nil?
    return true if direct_match?(shown)

    shown.wild? && substitutable_by_wild?(shown)
  end

  private
    def direct_match?(shown)
      game_symbol ? shown == game_symbol : symbol_group&.includes_symbol?(shown)
    end

    def substitutable_by_wild?(wild)
      if game_symbol
        wild.substitutes_for?(game_symbol)
      else
        symbol_group.game_symbols.any? { |member| wild.substitutes_for?(member) }
      end
    end

    # A wild substitutes for other symbols rather than paying for itself, so a
    # combination naming one describes something the game never does.
    def does_not_name_the_wild
      return if game_symbol.nil? || !game_symbol.wild?

      errors.add(:game_symbol, "is wild, and a wild substitutes rather than paying")
    end

    def names_exactly_one_thing
      return if game_symbol.present? ^ symbol_group.present?

      errors.add(:base, "A matcher names one symbol or one group, not both and not neither")
    end

    def belongs_to_the_entry_s_game
      game = paytable_entry&.variation&.game
      return if game.nil?

      named = game_symbol || symbol_group
      return if named.nil? || named.game_id == game.id

      errors.add(:base, "#{named.class.name.underscore.humanize} belongs to a different game")
    end
end
