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

  # The counts a paytable can pay for: two of a kind up to a full line. Nothing pays
  # for a single symbol, so the grid does not offer it.
  def payable_counts
    PaytableEntry::MINIMUM_COUNT..reel_count.to_i
  end

  # Typed input is matched case insensitively, so "a" finds the symbol whose code is
  # "A". Returns the symbol's actual code, or nil when nothing matches.
  def resolve_code(token)
    symbol_codes_by_downcase[token.to_s.strip.downcase]
  end

  private
    def symbol_codes_by_downcase
      @symbol_codes_by_downcase ||= symbols.pluck(:code).index_by(&:downcase)
    end

    def create_first_variation
      variations.create!(number: 1)
    end
end
