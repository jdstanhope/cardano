class Variation < ApplicationRecord
  NUMBERS = 1..99

  belongs_to :game

  has_many :reel_strips, -> { order(:position) }, dependent: :destroy
  has_many :paytable_entries, dependent: :destroy

  # Two digits, padded below ten: 01, 02, 99. Stored as an integer and padded for
  # display, so "1" and "01" cannot be different values for the same variation and
  # ordering is numeric rather than alphabetical.
  validates :number, presence: true,
                     uniqueness: { scope: :game_id },
                     numericality: { only_integer: true, in: NUMBERS }

  # Basis points: 9600 is 96.00%. Stored as integers because the point of evaluating
  # every outcome is to produce exact figures, and a float target would undercut that.
  validates :target_rtp_min, :target_rtp_max,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            allow_nil: true

  validate :target_band_is_given_as_a_pair
  validate :target_band_is_not_inverted

  def label = format("%02d", number.to_i)

  def target_rtp_min_percentage = percentage(target_rtp_min)
  def target_rtp_max_percentage = percentage(target_rtp_max)

  private
    def percentage(basis_points)
      return if basis_points.nil?

      format("%.2f%%", basis_points / 100.0)
    end

    def target_band_is_given_as_a_pair
      return if target_rtp_min.nil? == target_rtp_max.nil?

      errors.add(:base, "Target RTP needs both a minimum and a maximum, or neither")
    end

    def target_band_is_not_inverted
      return if target_rtp_min.nil? || target_rtp_max.nil?
      return if target_rtp_min <= target_rtp_max

      errors.add(:target_rtp_min, "cannot be greater than the maximum")
    end
end
