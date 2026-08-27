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

    # The grid edits N-of-a-kind combinations, which are sequences of one repeated
    # symbol. Anything else a variation holds is left alone by it.
    def existing_entries
      @existing_entries ||= variation.paytable_entries.includes(matchers: :game_symbol).each_with_object({}) do |entry, found|
        symbol_id = repeated_symbol_id(entry)
        next if symbol_id.nil?

        (found[symbol_id] ||= {})[entry.length] = entry.payout
      end
    end

    def repeated_symbol_id(entry)
      ids = entry.matchers.map(&:game_symbol_id)
      ids.first if ids.any? && ids.uniq.length == 1 && entry.matchers.all? { |matcher| matcher.symbol_group_id.nil? }
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
      entry = find_repeated_entry(symbol_id, count)

      if payout.nil?
        entry&.destroy
      elsif entry
        entry.update!(payout: payout)
      else
        created = variation.paytable_entries.new(payout: payout)
        count.times { |index| created.matchers.build(position: index + 1, game_symbol_id: symbol_id) }
        created.save!
      end
    end

    def find_repeated_entry(symbol_id, count)
      variation.paytable_entries.includes(:matchers).find do |entry|
        entry.length == count && repeated_symbol_id(entry) == symbol_id
      end
    end
end
