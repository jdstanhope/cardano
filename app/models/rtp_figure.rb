# A return figure that was computed, kept so a change can be measured against what came
# before it. Tuning a game is the activity of making a change and seeing what it did,
# and without a record of the last figure that means remembering it.
#
# Carries a fingerprint of everything it was computed from, which serves two purposes:
# recognising that a configuration has not changed, so recomputing does not fill the
# history with identical rows, and recognising that it has, so a figure can be told it
# no longer describes the variation it belongs to.
#
# A figure may have been evaluated or sampled, and a sampled one carries what it might be
# out by, how sure that is, how many spins it took and how often each combination landed.
# An exact figure carries none of those, which is the record of how it was arrived at
# rather than a gap in it.
class RtpFigure < ApplicationRecord
  belongs_to :variation

  validates :numerator, :denominator, :fingerprint, :computed_by, presence: true
  validates :denominator, numericality: { other_than: 0 }

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  def self.record(variation, result, spins: nil, coverage: nil)
    description = RtpFingerprint.new(variation)
    fingerprint = description.to_s
    latest = variation.rtp_figures.newest_first.first

    # An unchanged configuration *evaluates* to the same figure, and recording it again
    # would make the history unreadable for the case it exists to serve.
    #
    # Sampling breaks that premise on both sides. Two runs of one configuration
    # legitimately differ, so a sampled figure never settles anything; and a stored
    # sampled figure never settles an exact one, or computing exactly would hand back the
    # estimate and throw the better answer away.
    return latest if result.exact? && latest&.exact? && latest.fingerprint == fingerprint

    variation.rtp_figures.create!(
      numerator: result.value.numerator,
      denominator: result.value.denominator,
      computed_by: result.method,
      fingerprint: fingerprint,
      inputs: description.inputs,
      half_width: measurable(result.interval&.half_width),
      confidence: result.interval&.confidence,
      spins: spins,
      coverage: coverage&.map(&:to_h)
    )
  end

  # A run too short to have any spread says its interval is infinite, which is true and
  # is not a number a column can hold. Stored as nothing, which reads the same way.
  def self.measurable(half_width)
    half_width if half_width&.finite?
  end
  private_class_method :measurable

  # Rebuilt as the exact fraction it was stored as, not as a decimal that happens to
  # look the same.
  def value = Rational(numerator.to_i, denominator.to_i)

  def to_result = Rtp::Result.new(value: value, method: computed_by.to_sym, interval: interval)

  # What this figure might be out by, or nothing for an exact one — which is not out by
  # anything, rather than out by an amount nobody recorded.
  def interval
    return if half_width.nil? || confidence.nil?

    Rtp::Interval.new(half_width: half_width.to_f, confidence: confidence)
  end

  def exact? = to_result.exact?
  def to_percentage(places = 2) = to_result.to_percentage(places)
  def basis_points = to_result.basis_points

  # The difference from an earlier figure, in percentage points.
  def points_from(other) = ((value - other.value) * 100).to_f

  # What changed between an earlier figure and this one. Nil when either has no stored
  # description — figures recorded before snapshots existed cannot be compared, and
  # saying nothing is better than implying nothing changed.
  def changes_from(other)
    return if inputs.blank? || other&.inputs.blank?

    ConfigurationDiff.new(other.inputs, inputs)
  end
end
