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

  # What this wild does not substitute for, and the exclusions naming it. Both are
  # dependent, so removing either symbol takes the exclusion with it.
  has_many :wild_exclusions, foreign_key: :wild_id, dependent: :destroy, inverse_of: :wild
  has_many :excluded_symbols, through: :wild_exclusions, source: :excluded
  has_many :exclusions_naming_this_symbol, class_name: "WildExclusion", foreign_key: :excluded_id,
           dependent: :destroy, inverse_of: :excluded

  validates :code, presence: true, uniqueness: { scope: :game_id, case_sensitive: false }
  validates :position, presence: true, numericality: { only_integer: true }

  # A wild substitutes rather than paying, so a game has at most one. It may have
  # none — plenty of games do not use one at all.
  validate :only_one_wild_per_game
  validate :not_still_paying, if: :wild?

  # A symbol called Wild is the wild, not merely defaulted to one. Matched exactly
  # rather than by substring, so Wildcat is left alone. Applied on every save rather
  # than only on creation, so the name and the marking cannot disagree.
  before_validation :recognise_a_symbol_named_wild

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

  # A symbol that is not wild substitutes for nothing, so a list of what it does not
  # substitute for means nothing either.
  after_update :discard_exclusions_when_no_longer_wild, if: -> { saved_change_to_wild? && !wild? }

  def display_name
    name.presence || code
  end

  # A wild substitutes for every symbol in its game except itself and the ones it has
  # been told to leave alone. Anything that is not wild substitutes for nothing.
  def substitutes_for?(symbol)
    return false unless wild?
    return false if symbol == self

    excluded_symbols.exclude?(symbol)
  end

  # Named Wild, so the marking is not a choice: it cannot be unmarked, and nothing
  # else in the game can be marked while it is here.
  def named_wild? = name.to_s.strip.casecmp?("wild")

  # Strips reference symbols by code rather than by id, because a Postgres array cannot
  # carry a foreign key. Nothing at the database level protects this, so it is checked
  # here.
  def reel_strips_landing_on_it
    ReelStrip.joins(:variation)
             .where(variations: { game_id: game_id })
             .where("? = ANY (symbols)", code)
  end

  private
    def discard_exclusions_when_no_longer_wild
      wild_exclusions.destroy_all
    end

    def recognise_a_symbol_named_wild
      self.wild = true if name.to_s.strip.casecmp?("wild")
    end

    def only_one_wild_per_game
      return unless wild?
      return if game.nil?

      already = game.symbols.wild.where.not(id: id)
      return if already.empty?

      errors.add(:base, "#{already.first.display_name} is already the wild for this game, and a game has one wild at most.")
    end

    # A wild does not pay for itself, so marking one that still has payouts would
    # quietly strand them. Refusing matches how removal already behaves: nothing is
    # destroyed by a checkbox.
    def not_still_paying
      return if paytable_entries.empty?

      counts = paytable_entries.order(:count).pluck(:count).map { |count| "x#{count}" }
      errors.add(:base, "#{display_name} cannot be wild while it still pays #{counts.to_sentence}. Clear those first.")
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
