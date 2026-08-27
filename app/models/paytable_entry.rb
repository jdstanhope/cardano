# What one combination pays.
#
# A combination is an ordered sequence of matchers, one per reel from the leftmost.
# Three of a kind is a sequence of the same symbol three times rather than a special
# case, and that is what lets a paytable express R7 W7 B7, or any red then any white
# then any blue, in the same shape.
class PaytableEntry < ApplicationRecord
  MINIMUM_LENGTH = 2

  belongs_to :variation

  has_many :matchers, -> { order(:position) }, class_name: "PaytableMatcher", dependent: :destroy
  has_one :game, through: :variation

  validates :payout, presence: true, numericality: { only_integer: true, greater_than: 0 }

  validate :long_enough_to_be_a_combination
  validate :fits_the_reels

  # The symbols and groups this combination accepts, in order.
  def sequence = matchers.map(&:label)

  def length = matchers.size

  # Whether this is the same symbol repeated — the only shape the grid can express.
  # Everything else has to be read and edited as a sequence.
  def n_of_a_kind? = repeated_symbol_id.present?

  # The symbol this repeats, or nil if it is anything else.
  def repeated_symbol_id
    ids = matchers.map(&:game_symbol_id)
    ids.first if ids.any? && ids.uniq.length == 1 && matchers.all? { |matcher| matcher.symbol_group_id.nil? }
  end

  # Whether a line of symbols, one per reel from the leftmost, satisfies this
  # combination. A longer line is fine: the combination occupies its opening reels.
  def matches?(symbols_on_line)
    return false if matchers.empty? || symbols_on_line.length < length

    matchers.each_with_index.all? { |matcher, index| matcher.matches?(symbols_on_line[index]) }
  end

  private
    def long_enough_to_be_a_combination
      return if matchers.size >= MINIMUM_LENGTH

      errors.add(:base, "A combination is at least #{MINIMUM_LENGTH} symbols; nothing pays for one")
    end

    def fits_the_reels
      return if game.nil? || matchers.size <= game.reel_count

      errors.add(:base, "A combination cannot be longer than the #{game.reel_count} reels the game has")
    end
end
