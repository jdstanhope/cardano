# A symbol's membership of a group. A symbol belongs to several groups on purpose — a
# red seven is both a seven and a red, and a real paytable pays for both separately.
class SymbolGroupMembership < ApplicationRecord
  belongs_to :symbol_group
  belongs_to :game_symbol

  validates :game_symbol_id, uniqueness: { scope: :symbol_group_id }

  validate :both_belong_to_one_game

  private
    def both_belong_to_one_game
      return if symbol_group.nil? || game_symbol.nil?
      return if symbol_group.game_id == game_symbol.game_id

      errors.add(:game_symbol, "belongs to a different game")
    end
end
