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

  # A wild substitutes rather than paying, so a game has at most one. It may have
  # none — plenty of games do not use one at all.
  validate :only_one_wild_per_game
  validate :not_still_paying, if: :wild?

  # The common case needs no extra step: a symbol called Wild is one. Matched exactly
  # rather than by substring, so Wildcat is left alone.
  before_validation :recognise_a_symbol_named_wild, on: :create

  scope :wild, -> { where(wild: true) }

  # Removing a symbol on its own is refused while anything still uses it. Removing one
  # as part of its game is not — that is the cascade above, and guarding it here would
  # make deleting a game fail as soon as it had a paytable.
  #
  # prepend: true matters. `dependent: :destroy` registers its own before_destroy when
  # the association is declared, which is before this line, so without prepending, the
  # entries are deleted first and this guard then finds nothing to object to — the
  # symbol goes, and its paytable with it, silently.
  before_destroy :refuse_while_in_use, prepend: true, unless: :destroyed_by_association

  def display_name
    name.presence || code
  end

  # Strips reference symbols by code rather than by id, because a Postgres array cannot
  # carry a foreign key. Nothing at the database level protects this, so it is checked
  # here.
  def reel_strips_landing_on_it
    ReelStrip.joins(:variation)
             .where(variations: { game_id: game_id })
             .where("? = ANY (symbols)", code)
  end

  private
    def recognise_a_symbol_named_wild
      self.wild = true if name.to_s.strip.casecmp?("wild")
    end

    def only_one_wild_per_game
      return unless wild?
      return if game.nil?

      already = game.symbols.wild.where.not(id: id)
      return if already.empty?

      errors.add(:wild, "is already set on #{already.first.display_name}; a game has one wild at most")
    end

    # A wild does not pay for itself, so marking one that still has payouts would
    # quietly strand them. Refusing matches how removal already behaves: nothing is
    # destroyed by a checkbox.
    def not_still_paying
      return if paytable_entries.empty?

      counts = paytable_entries.order(:count).pluck(:count).map { |count| "x#{count}" }
      errors.add(:wild, "cannot be set while #{display_name} still pays #{counts.to_sentence}. Clear those first.")
    end

    def refuse_while_in_use
      users = []

      strips = reel_strips_landing_on_it.includes(:variation).order(:position)
      if strips.any?
        described = strips.map { |strip| "reel #{strip.position} of variation #{strip.variation.label}" }
        users << "reel strips (#{described.to_sentence})"
      end

      counts = paytable_entries.order(:count).pluck(:count)
      users << "paytable entries (#{counts.map { |c| "x#{c}" }.to_sentence})" if counts.any?

      return if users.empty?

      errors.add(:base, "#{display_name} is still used by #{users.to_sentence}. Remove those first.")
      throw :abort
    end
end
