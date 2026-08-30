# Everything a return figure depends on, reduced to one value.
#
# Used to tell whether a figure still describes the variation it belongs to. The bar is
# that it covers every input to the calculation: anything left out means a change to it
# reads as "nothing changed", which is worse than showing nothing at all, because it is
# wrong rather than absent.
#
# So it covers the reel window and mechanic, the paylines, the strips, the paytable
# combinations in order, the groups those combinations name, and which symbols are wild
# and what they do not substitute for. Everything is sorted into a canonical order, so
# the same description fingerprints the same way whatever order it was read in.
class RtpFingerprint
  # Bumped when the evaluation rules change. The same description can be worth a
  # different figure after a change to how combinations are matched, and comparing
  # across that would report a difference the person did not make.
  VERSION = 1

  def self.for(variation) = new(variation).to_s

  # The description itself, which is what a diff compares and a restore puts back.
  # Taken from the same builder as the hash, so the two cannot disagree about what a
  # figure was computed from.
  def self.inputs_for(variation) = new(variation).inputs

  def initialize(variation)
    @variation = variation
    @game = variation.game
  end

  def to_s = Digest::SHA256.hexdigest(JSON.generate(inputs))

  def inputs
    {
      version: VERSION,
      window: [ @game.reel_count, @game.row_count ],
      mechanic: @game.win_mechanic,
      paylines: @game.paylines.order(:position).map(&:rows),
      symbols: symbols,
      groups: groups,
      strips: @variation.reel_strips.order(:position).map(&:symbols),
      paytable: paytable
    }
  end

  private
    # A symbol matters to the calculation for its code, whether it is wild, and what a
    # wild refuses to stand in for. Its display name does not.
    def symbols
      @game.symbols.sort_by(&:code).map do |symbol|
        [ symbol.code, symbol.wild?, symbol.excluded_symbols.map(&:code).sort ]
      end
    end

    def groups
      @game.symbol_groups.map { |group| [ group.name, group.game_symbols.map(&:code).sort ] }.sort
    end

    # Order within a combination is part of what it means, so matchers keep theirs.
    # Order between combinations is not, so they are sorted.
    def paytable
      @variation.paytable.map { |entry| [ entry.payout, entry.matchers.sort_by(&:position).map { |matcher| token(matcher) } ] }.sort
    end

    def token(matcher)
      matcher.symbol_group ? [ "group", matcher.symbol_group.name ] : [ "symbol", matcher.game_symbol.code ]
    end
end
