# Copies a game, in full, into an account.
#
# A game is a deep object — symbols, groups pointing at symbols, wild substitution
# rules pointing at symbols, paylines, and variations whose strips and paytable
# combinations point back at those same symbols and groups. Copying it means rebuilding
# every one of those references against the new records.
#
# The danger is a reference that still points at the original's rows. It would not raise:
# the copy would look right and quietly share a paytable with the game it came from. So
# nothing here copies an id. Every association is rewired through a map built while the
# records are created, and a lookup for something that was never mapped raises rather
# than returning nil.
class GameDuplication
  def initialize(game, owner:, name: nil)
    @source = game
    @owner = owner
    @name = name
  end

  def self.call(...) = new(...).call

  def call
    Game.transaction do
      @copy = @owner.games.create!(attributes_of(@source).merge(name: name))

      copy_symbols
      copy_groups
      copy_wild_exclusions
      copy_paylines
      copy_variations

      @copy
    end
  end

  def name = @name.presence || GameName.free_for(@owner, "#{@source.name} (copy)")

  private
    def symbols = @symbols ||= {}
    def groups = @groups ||= {}

    def copy_symbols
      @source.symbols.order(:position).each do |symbol|
        symbols[symbol.id] = @copy.symbols.create!(attributes_of(symbol))
      end
    end

    def copy_groups
      @source.symbol_groups.each do |group|
        copied = @copy.symbol_groups.create!(attributes_of(group))
        group.symbol_group_memberships.each do |membership|
          copied.symbol_group_memberships.create!(game_symbol: symbol_for(membership.game_symbol_id))
        end
        groups[group.id] = copied
      end
    end

    # Which symbols a wild does not substitute for. Copied after every symbol exists,
    # since an exclusion names two of them.
    def copy_wild_exclusions
      @source.symbols.each do |symbol|
        symbol.wild_exclusions.each do |exclusion|
          symbol_for(symbol.id).wild_exclusions.create!(excluded: symbol_for(exclusion.excluded_id))
        end
      end
    end

    def copy_paylines
      @source.paylines.each { |payline| @copy.paylines.create!(attributes_of(payline)) }
    end

    def copy_variations
      @source.variations.each_with_index do |variation, index|
        # A game creates its first variation on creation, so the copy already has one to
        # fill in rather than add alongside.
        copied = index.zero? ? @copy.variations.first : @copy.variations.new
        copied.update!(attributes_of(variation))

        variation.reel_strips.each { |strip| copied.reel_strips.create!(attributes_of(strip)) }
        variation.paytable_entries.each { |entry| copy_paytable_entry(entry, into: copied) }
      end
    end

    def copy_paytable_entry(entry, into:)
      copied = into.paytable_entries.new(attributes_of(entry))

      entry.matchers.each do |matcher|
        copied.matchers.build(
          position: matcher.position,
          game_symbol: matcher.game_symbol_id && symbol_for(matcher.game_symbol_id),
          symbol_group: matcher.symbol_group_id && group_for(matcher.symbol_group_id)
        )
      end

      copied.save!
    end

    def symbol_for(id) = symbols.fetch(id)
    def group_for(id) = groups.fetch(id)

    IGNORED = %w[ id game_id user_id variation_id symbol_group_id created_at updated_at ].freeze

    def attributes_of(record) = record.attributes.except(*IGNORED)
end
