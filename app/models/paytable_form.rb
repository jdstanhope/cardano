# Collects a variation's whole paytable into one save.
#
# The grid is edited as a unit, so one bad cell should not leave some entries updated
# and others not. Everything is validated first and the write happens in a transaction
# that rolls back if anything is rejected — the same reasoning as ReelStripsForm.
class PaytableForm
  include ActiveModel::Model

  attr_reader :variation, :submitted, :errors_by_cell

  def initialize(variation:, payouts: {})
    @variation = variation
    @submitted = normalize(payouts)
    @errors_by_cell = {}
  end

  def save
    resolved = resolve_every_cell
    return false if errors_by_cell.any?

    variation.transaction do
      resolved.each { |(symbol_id, count), payout| write(symbol_id, count, payout) }
    end

    true
  end

  def error_for(symbol, count) = errors_by_cell[[ symbol.id, count ]]

  # What to show in each cell: what was submitted if the save was rejected, so nobody
  # loses their typing, otherwise what is stored.
  def value_for(symbol, count)
    return submitted.dig([ symbol.id, count ]) if submitted.key?([ symbol.id, count ])

    existing_entries.dig(symbol.id, count)
  end

  private
    def game = variation.game

    def normalize(payouts)
      (payouts || {}).each_with_object({}) do |(symbol_id, counts), normalized|
        (counts || {}).each do |count, value|
          normalized[[ symbol_id.to_i, count.to_i ]] = value.to_s.strip
        end
      end
    end

    def existing_entries
      @existing_entries ||= variation.paytable_entries.group_by(&:game_symbol_id).transform_values do |entries|
        entries.to_h { |entry| [ entry.count, entry.payout ] }
      end
    end

    def payable_symbol_ids = @payable_symbol_ids ||= game.symbols.pluck(:id).to_set

    def resolve_every_cell
      submitted.each_with_object({}) do |((symbol_id, count), value), resolved|
        unless payable_symbol_ids.include?(symbol_id)
          errors_by_cell[[ symbol_id, count ]] = "not a symbol in this game"
          next
        end

        if value.blank?
          resolved[[ symbol_id, count ]] = nil
          next
        end

        payout = Integer(value, exception: false)

        if payout.nil? || payout <= 0
          errors_by_cell[[ symbol_id, count ]] = "must be a positive whole number"
        else
          resolved[[ symbol_id, count ]] = payout
        end
      end
    end

    def write(symbol_id, count, payout)
      entry = variation.paytable_entries.find_or_initialize_by(game_symbol_id: symbol_id, count: count)

      if payout.nil?
        entry.destroy if entry.persisted?
      else
        entry.update!(payout: payout)
      end
    end
end
