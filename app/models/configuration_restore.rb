# Putting a variation back to a configuration it held earlier.
#
# Only the variation's own description: its reel strips and its paytable. Symbols,
# groups, paylines, the reel window and the mechanic belong to the game and are shared
# with every other variation of it, so putting those back would silently rewrite what
# the others compute. Where the game has moved on, this says so rather than pretending
# the figure will land where it did before.
#
# Restoring appends. It produces a new figure like any other change, so the
# configuration being left behind stays in the history and stays restorable — which is
# what makes going back safe rather than destructive.
class ConfigurationRestore
  attr_reader :variation, :figure

  def initialize(figure, into: nil)
    @figure = figure
    @variation = into || figure.variation
    @snapshot = (figure.inputs || {}).with_indifferent_access
  end

  def possible? = refusals.empty?

  # Why this cannot be put back. A snapshot naming a symbol or group the game no longer
  # has describes something that cannot exist now; restoring the rest would produce a
  # paytable nobody asked for.
  def refusals
    @refusals ||= [].tap do |reasons|
      reasons << "it was recorded before configurations were kept" if figure.inputs.blank?
      next if figure.inputs.blank?

      missing_symbols = (snapshot_symbol_codes - existing_symbol_codes).uniq
      missing_groups = (snapshot_group_names - existing_group_names).uniq

      reasons << "#{"symbol".pluralize(missing_symbols.size)} #{missing_symbols.to_sentence} no longer exist" if missing_symbols.any?
      reasons << "#{"group".pluralize(missing_groups.size)} #{missing_groups.to_sentence} no longer exist" if missing_groups.any?
    end
  end

  # What will be put back.
  def restoring
    [].tap do |summary|
      summary << "#{strips.length} reel #{"strip".pluralize(strips.length)}, #{strips.sum(&:length)} stops in total" if strips.any?
      summary << "#{paytable.length} paytable #{"combination".pluralize(paytable.length)}" if paytable.any?
    end
  end

  # What will not, because it belongs to the game. Empty when the game has not moved
  # since, which is the case where the figure will land exactly where it did.
  def leaving_alone = differences.of_the_game

  def figure_will_differ? = leaving_alone.any?

  def call
    raise ArgumentError, refusals.to_sentence unless possible?

    Variation.transaction do
      variation.reel_strips.destroy_all
      strips.each_with_index { |codes, index| variation.reel_strips.create!(position: index + 1, symbols: codes) }

      variation.paytable_entries.destroy_all
      paytable.each { |payout, sequence| write_combination(payout, sequence) }
    end

    variation
  end

  private
    def game = variation.game

    # Read afresh rather than through whatever the associations happen to hold. A
    # restore decides what may be written from what is in the database now, and a
    # symbol deleted a moment ago must not still look present.
    def existing_symbol_codes = @existing_symbol_codes ||= game.symbols.reload.map(&:code)
    def existing_group_names = @existing_group_names ||= game.symbol_groups.reload.map(&:name)

    def strips = @strips ||= Array(@snapshot[:strips]).map { |codes| Array(codes) }
    def paytable = @paytable ||= Array(@snapshot[:paytable])

    def snapshot_symbol_codes
      strips.flatten + paytable.flat_map { |_, sequence| Array(sequence).select { |kind, _| kind == "symbol" }.map(&:last) }
    end

    def snapshot_group_names
      paytable.flat_map { |_, sequence| Array(sequence).select { |kind, _| kind == "group" }.map(&:last) }
    end

    # Against the description as it stands now, so the warning is about what has moved
    # since rather than about the restore itself.
    def differences = @differences ||= ConfigurationDiff.new(@snapshot, RtpFingerprint.inputs_for(variation))

    def write_combination(payout, sequence)
      entry = variation.paytable_entries.new(payout: payout)

      Array(sequence).each_with_index do |(kind, name), index|
        named = kind == "group" ? groups.fetch(name) : symbols.fetch(name)
        key = kind == "group" ? :symbol_group : :game_symbol
        entry.matchers.build(position: index + 1, key => named)
      end

      entry.save!
    end

    def symbols = @symbols ||= game.symbols.index_by(&:code)
    def groups = @groups ||= game.symbol_groups.index_by(&:name)
end
