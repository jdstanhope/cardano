# A new variation holding a configuration one of its siblings has, or had.
#
# Variations exist to hold alternative reel strips and paytables for the same game, and
# the game page already compares them. So trying an alternative is copying a
# configuration into a fresh variation rather than editing the one that works — and
# branching a checkpoint is the same thing with a configuration from the history.
#
# The source is untouched, and nothing belonging to the game is copied, because a
# variation shares its symbols, groups, paylines, window and mechanic with every other
# variation of that game. There is nothing to copy: the new one already has them.
class VariationBranch
  attr_reader :source, :figure

  # From a figure when branching a checkpoint, from the variation itself when copying
  # what it holds now. Both are a configuration and a variation to read it from.
  def self.from_figure(figure) = new(figure.variation, figure: figure)
  def self.from_variation(variation) = new(variation)

  def initialize(source, figure: nil)
    @source = source
    @figure = figure
  end

  def game = source.game

  def possible? = refusals.empty?

  def refusals
    @refusals ||= [].tap do |reasons|
      reasons << "#{game.name} already has all #{Variation::NUMBERS.count} variations" if game.next_variation_number.nil?
      reasons.concat(restore_of(source).refusals) if figure
    end
  end

  # What the new variation will hold, said before it exists.
  def carrying = figure ? restore_of(source).restoring : current_description

  def call
    raise ArgumentError, refusals.to_sentence unless possible?

    Variation.transaction do
      branch = game.variations.create!(number: game.next_variation_number,
                                       target_rtp_min: source.target_rtp_min,
                                       target_rtp_max: source.target_rtp_max)

      ConfigurationRestore.new(configuration, into: branch).call

      branch
    end
  end

  private
    # A branch from a checkpoint carries that checkpoint's configuration; a branch from
    # the variation carries what it holds now. Reusing the figure record means one way
    # of describing a configuration rather than two.
    def configuration = figure || RtpFigure.new(variation: source, inputs: RtpFingerprint.inputs_for(source))

    def restore_of(variation) = ConfigurationRestore.new(configuration, into: variation)

    def current_description
      strips = source.reel_strips.map { |strip| strip.symbols.length }

      [].tap do |summary|
        summary << "#{strips.length} reel #{"strip".pluralize(strips.length)}, #{strips.sum} stops in total" if strips.any?
        summary << "#{source.paytable_entries.count} paytable #{"combination".pluralize(source.paytable_entries.count)}" if source.paytable_entries.any?
      end
    end
end
