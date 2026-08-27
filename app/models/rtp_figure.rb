# A return figure that was computed, kept so a change can be measured against what came
# before it. Tuning a game is the activity of making a change and seeing what it did,
# and without a record of the last figure that means remembering it.
#
# Carries a fingerprint of everything it was computed from, which serves two purposes:
# recognising that a configuration has not changed, so recomputing does not fill the
# history with identical rows, and recognising that it has, so a figure can be told it
# no longer describes the variation it belongs to.
class RtpFigure < ApplicationRecord
  belongs_to :variation

  validates :numerator, :denominator, :fingerprint, :computed_by, presence: true
  validates :denominator, numericality: { other_than: 0 }

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  def self.record(variation, result)
    fingerprint = RtpFingerprint.for(variation)
    latest = variation.rtp_figures.newest_first.first

    # An unchanged configuration recomputes to the same figure. Recording it again
    # would make the history unreadable for the case it exists to serve.
    return latest if latest&.fingerprint == fingerprint

    variation.rtp_figures.create!(
      numerator: result.value.numerator,
      denominator: result.value.denominator,
      computed_by: result.method,
      fingerprint: fingerprint
    )
  end

  # Rebuilt as the exact fraction it was stored as, not as a decimal that happens to
  # look the same.
  def value = Rational(numerator.to_i, denominator.to_i)

  def to_result = Rtp::Result.new(value: value, method: computed_by.to_sym)

  def exact? = to_result.exact?
  def to_percentage(places = 2) = to_result.to_percentage(places)
  def basis_points = to_result.basis_points

  # The difference from an earlier figure, in percentage points.
  def points_from(other) = ((value - other.value) * 100).to_f
end
