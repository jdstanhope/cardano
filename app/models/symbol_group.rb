# A named set of symbols a paytable combination can accept: sevens, bars, reds.
#
# Named once and referenced by many combinations, so adding a symbol to a group updates
# every combination that uses it. Entries carrying their own list of symbols would mean
# retyping the same list and watching the copies drift apart.
class SymbolGroup < ApplicationRecord
  belongs_to :game

  has_many :symbol_group_memberships, dependent: :destroy
  has_many :game_symbols, through: :symbol_group_memberships

  validates :name, presence: true, uniqueness: { scope: :game_id, case_sensitive: false }
  validates :position, presence: true, numericality: { only_integer: true }

  def includes_symbol?(symbol) = game_symbols.include?(symbol)
end
