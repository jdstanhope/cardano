class Variation < ApplicationRecord
  NUMBERS = 1..99

  belongs_to :game

  has_many :reel_strips, -> { order(:position) }, dependent: :destroy
  has_many :paytable_entries, dependent: :destroy
  has_many :rtp_figures, dependent: :destroy
  has_many :calculations, dependent: :destroy

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

  # The combinations this variation pays for, with their matchers loaded: the mechanics
  # ask each one whether it matches, so they are read many times over.
  def paytable
    paytable_entries.includes(matchers: [ :game_symbol, { symbol_group: :game_symbols } ]).to_a
  end

  def rtp = Rtp.new(self).call

  # Computes the figure and keeps it, so a later change has something to be measured
  # against. A configuration that has not changed since the last figure records nothing
  # further; an incomplete description has no figure to record.
  def record_rtp
    result = rtp
    RtpFigure.record(self, result) if result.respond_to?(:exact?)
    result
  end

  def latest_rtp_figure = rtp_figures.newest_first.first

  # The figure before the most recent one, which is what a change is measured against.
  # Nil until a second figure exists, and a variation that has never been changed
  # legitimately has nothing to compare with.
  def previous_rtp_figure = rtp_figures.newest_first.second

  def rtp_history(limit = 10) = rtp_figures.newest_first.limit(limit).to_a

  def missing_for_rtp = Rtp.new(self).missing_pieces

  # Whether the figure on hand was computed from the description as it stands. A figure
  # for an earlier description is still worth showing — it is the last thing known —
  # but showing it as current would be presenting a wrong number authoritatively.
  def rtp_figure_current?
    figure = latest_rtp_figure
    figure.present? && figure.fingerprint == RtpFingerprint.for(self)
  end

  # Started on view when there is nothing current and nothing already in flight.
  # Editing a strip should not queue a run per keystroke, and a run already going will
  # answer the same question.
  def calculation_wanted? = missing_for_rtp.empty? && !rtp_figure_current? && calculations.in_flight.none?

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
