# Collects every reel of a variation into one save.
#
# All of a variation's strips are edited together, so one bad code should not leave
# half the reels updated and half not. Everything is validated first, and the write
# happens in a transaction that rolls back if anything is rejected.
class ReelStripsForm
  include ActiveModel::Model

  SEPARATORS = /[\s,]+/

  attr_reader :variation, :submitted, :errors_by_position

  def initialize(variation:, reels: {})
    @variation = variation
    @submitted = (reels || {}).to_h { |position, text| [ position.to_i, text.to_s ] }
    @errors_by_position = {}
  end

  def save
    resolved = resolve_every_reel
    return false if errors_by_position.any?

    variation.transaction do
      resolved.each { |position, codes| write(position, codes) }
    end

    true
  end

  def error_for(position) = errors_by_position[position]

  # What should be shown in each text area: what was just submitted if the save was
  # rejected, so nobody loses their typing, otherwise what is stored.
  def text_for(position)
    submitted[position] || variation.reel_strips.find { |strip| strip.position == position }&.symbols&.join(" ") || ""
  end

  private
    def game = variation.game

    def resolve_every_reel
      submitted.each_with_object({}) do |(position, text), resolved|
        tokens = text.split(SEPARATORS).reject(&:blank?)
        codes = tokens.map { |token| game.resolve_code(token) }

        unknown = tokens.zip(codes).reject { |_, code| code }.map(&:first).uniq
        if unknown.any?
          errors_by_position[position] = "#{unknown.to_sentence} #{unknown.one? ? "is not" : "are not"} a symbol in this game"
        end

        resolved[position] = codes
      end
    end

    def write(position, codes)
      strip = variation.reel_strips.find_or_initialize_by(position: position)

      if codes.empty?
        strip.destroy if strip.persisted?
      else
        strip.update!(symbols: codes)
      end
    end
end
