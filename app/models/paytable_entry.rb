class PaytableEntry < ApplicationRecord
  belongs_to :variation
  belongs_to :game_symbol

  has_one :game, through: :variation

  validates :count, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :payout, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :game_symbol_id, uniqueness: { scope: [ :variation_id, :count ] }

  validate :count_is_reachable_in_the_window
  validate :symbol_belongs_to_the_same_game

  private
    def count_is_reachable_in_the_window
      return if game.nil? || count.nil?
      return if count <= game.reel_count

      errors.add(:count, "cannot exceed the #{game.reel_count} reels the game has")
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
