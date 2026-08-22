# Deliberately not called Symbol. A top-level Symbol < ApplicationRecord would shadow
# Ruby's ::Symbol across the whole application, and namespacing it as Game::Symbol has
# the same problem inside `class Game`, where a bare Symbol would resolve to the model.
# The association still reads game.symbols.
class GameSymbol < ApplicationRecord
  belongs_to :game

  # A paytable entry cannot outlive the symbol it pays for. Declaring this makes the
  # destroy cascade correct regardless of the order associations happen to run in:
  # without it, destroying a game removes its symbols while paytable entries still
  # reference them, and Postgres rejects it.
  has_many :paytable_entries, dependent: :destroy

  validates :code, presence: true, uniqueness: { scope: :game_id, case_sensitive: false }
  validates :position, presence: true, numericality: { only_integer: true }

  def display_name
    name.presence || code
  end
end
