class PaytableEntry < ApplicationRecord
  MINIMUM_COUNT = 2

  belongs_to :variation
  belongs_to :game_symbol

  has_one :game, through: :variation

  # A combination is at least two symbols. Nothing pays for a single one, even on a
  # small window, so a count of 1 is a mistake rather than an unusual design.
  validates :count, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: MINIMUM_COUNT }
  validates :payout, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :game_symbol_id, uniqueness: { scope: [ :variation_id, :count ] }

  validate :count_is_reachable_in_the_window
  validate :symbol_belongs_to_the_same_game
  validate :symbol_is_not_wild

  private
    def count_is_reachable_in_the_window
      return if game.nil? || count.nil?
      return if count <= game.reel_count

      errors.add(:count, "cannot exceed the #{game.reel_count} reels the game has")
    end

    # A wild substitutes for other symbols rather than paying for itself, so an entry
    # paying for one describes something the game never does.
    def symbol_is_not_wild
      return if game_symbol.nil? || !game_symbol.wild?

      errors.add(:game_symbol, "is wild, and a wild substitutes rather than paying")
    end

    # Both records reach a game, and nothing else stops them being different ones.
    # An entry for a symbol from another game describes a combination that can
    # never land, which would quietly skew the figures rather than raise.
    def symbol_belongs_to_the_same_game
      return if game.nil? || game_symbol.nil?
      return if game_symbol.game_id == game.id

      errors.add(:game_symbol, "belongs to a different game")
    end
end
