class Game < ApplicationRecord
  belongs_to :user

  has_many :symbols, class_name: "GameSymbol", dependent: :destroy
  has_many :paylines, dependent: :destroy
  has_many :variations, dependent: :destroy

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
end
