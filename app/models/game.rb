class Game < ApplicationRecord
  belongs_to :user

  has_many :symbols, class_name: "GameSymbol", dependent: :destroy
  has_many :paylines, dependent: :destroy
  has_many :variations, -> { order(:number) }, dependent: :destroy

  # A variation is where reel strips and the paytable live, so a game without one
  # cannot hold any maths. Every game arrives with 01 rather than requiring it as a
  # separate step.
  after_create :create_first_variation

  validates :name, presence: true, uniqueness: { scope: :user_id }
  validates :win_mechanic, inclusion: { in: WinMechanic::NAMES }

  validate :ways_games_have_no_paylines
  validates :reel_count, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :row_count, presence: true, numericality: { only_integer: true, greater_than: 0 }

  # Row indices run top to bottom, descending, with zero at the centre, so the centre
  # line is [0, 0, ...] whatever the window height. An even window has one more row
  # below the centre than above it: four rows are 1, 0, -1, -2.
  def row_indices
    return [] unless row_count.to_i.positive?

    top_row.downto(bottom_row).to_a
  end

  def top_row
    (row_count.to_i - 1) / 2
  end

  def bottom_row
    top_row - (row_count.to_i - 1)
  end

  def row_range
    bottom_row..top_row
  end

  # Views count rows from the top; the domain counts them from the centre.
  def offset_from_top(row)
    top_row - row
  end

  def pays_by_ways? = win_mechanic == "ways"
  def pays_by_lines? = !pays_by_ways?

  def win_mechanic_for_evaluation = WinMechanic.for(self)

  # How many ways a ways game offers, which follows from the window rather than being
  # stored: five reels of three rows give 243.
  def ways_count = reel_count.to_i.times.reduce(1) { |total, _| total * row_count.to_i }

  def wild_symbol = symbols.wild.first

  # Whether another symbol could be made wild. False once one exists — offering the
  # option anyway produces a button whose only possible outcome is a refusal.
  def wild_available? = wild_symbol.nil?

  # The counts a paytable can pay for: two of a kind up to a full line. Nothing pays
  # for a single symbol, so the grid does not offer it.
  def payable_counts
    PaytableEntry::MINIMUM_COUNT..reel_count.to_i
  end

  # The lowest free number, rather than one past the highest, so deleting a variation
  # does not permanently consume its number. Nil once all ninety-nine are taken.
  def next_variation_number
    taken = variations.pluck(:number).to_set

    Variation::NUMBERS.find { |number| !taken.include?(number) }
  end

  # Typed input is matched case insensitively, so "a" finds the symbol whose code is
  # "A". Returns the symbol's actual code, or nil when nothing matches.
  def resolve_code(token)
    symbol_codes_by_downcase[token.to_s.strip.downcase]
  end

  private
    # Switching to ways would leave the paylines describing nothing. Refused rather
    # than discarding them, the same as marking a wild that still pays: a setting does
    # not destroy work as a side effect.
    def ways_games_have_no_paylines
      return unless pays_by_ways?
      return if paylines.empty?

      errors.add(:win_mechanic, "cannot be ways while the game has #{paylines.size} paylines. Remove them first.")
    end

    def symbol_codes_by_downcase
      @symbol_codes_by_downcase ||= symbols.pluck(:code).index_by(&:downcase)
    end

    def create_first_variation
      variations.create!(number: 1)
    end
end
