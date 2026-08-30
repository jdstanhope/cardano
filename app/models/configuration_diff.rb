# What changed between two descriptions of a variation.
#
# The fingerprint can say that something changed; this says what. It compares the same
# canonical structure the fingerprint is built from, so anything the figure depends on
# is something this can report — if it were built from anything narrower, a change
# could move the figure and go unmentioned, which reads as nothing having happened.
#
# Changes are split by what owns them. A variation owns its reel strips and paytable;
# symbols, groups, paylines, the window and the mechanic belong to the game and are
# shared with every other variation of it, so a change there was not necessarily made
# here and cannot be put back from here.
class ConfigurationDiff
  Change = Struct.new(:scope, :subject, :detail, keyword_init: true) do
    def to_s = detail.present? ? "#{subject}: #{detail}" : subject
    def variation? = scope == :variation
  end

  def initialize(before, after)
    @before = (before || {}).with_indifferent_access
    @after = (after || {}).with_indifferent_access
  end

  def changes = @changes ||= (strips + paytable + paylines + symbols + groups + window).compact

  def any? = changes.any?
  def none? = changes.empty?

  def of_the_variation = changes.select(&:variation?)
  def of_the_game = changes.reject(&:variation?)

  def to_a = changes.map(&:to_s)

  private
    def before(key) = @before[key]
    def after(key) = @after[key]

    def change(scope, subject, detail = nil) = Change.new(scope: scope, subject: subject, detail: detail)

    # Reported as counts rather than position by position. Inserting one stop shifts
    # every stop below it, which position-by-position reads as fifty changes when one
    # was made; the tally is what a designer is actually tracking anyway.
    def strips
      old = Array(before(:strips))
      new = Array(after(:strips))

      (0...[ old.length, new.length ].max).filter_map do |index|
        was, now = Array(old[index]), Array(new[index])
        next if was == now

        subject = "Reel #{index + 1}"
        next change(:variation, subject, "added") if was.empty?
        next change(:variation, subject, "removed") if now.empty?

        detail = tally_detail(was, now)
        detail ||= was.length == now.length ? "order changed" : "#{was.length} → #{now.length} stops"

        change(:variation, subject, detail)
      end
    end

    def tally_detail(was, now)
      moved = (tally(was).keys | tally(now).keys).sort.filter_map do |code|
        from, to = tally(was)[code].to_i, tally(now)[code].to_i
        "#{code} #{from} → #{to}" unless from == to
      end

      moved.join(", ") if moved.any?
    end

    def tally(codes) = codes.tally

    # Keyed by the sequence rather than by payout, so changing what a combination pays
    # reads as one change rather than as a removal and an addition.
    def paytable
      old = Array(before(:paytable)).to_h { |payout, sequence| [ label(sequence), payout ] }
      new = Array(after(:paytable)).to_h { |payout, sequence| [ label(sequence), payout ] }

      removed = (old.keys - new.keys).map { |sequence| change(:variation, sequence, "no longer pays") }
      added = (new.keys - old.keys).map { |sequence| change(:variation, sequence, "now pays #{new[sequence]}") }
      repriced = (old.keys & new.keys).filter_map do |sequence|
        change(:variation, sequence, "#{old[sequence]} → #{new[sequence]}") if old[sequence] != new[sequence]
      end

      removed + added + repriced
    end

    def label(sequence) = Array(sequence).map { |kind, name| kind == "group" ? "any #{name}" : name }.join(" ")

    def paylines
      was, now = Array(before(:paylines)), Array(after(:paylines))
      return [] if was == now

      detail = was.length == now.length ? "shapes changed" : "#{was.length} → #{now.length}"
      [ change(:game, "Paylines", detail) ]
    end

    # A symbol matters here for its code, whether it is wild, and what a wild refuses
    # to stand in for. Its display name changes no figure and is not in the snapshot.
    def symbols
      was = Array(before(:symbols)).to_h { |code, wild, excluded| [ code, [ wild, Array(excluded) ] ] }
      now = Array(after(:symbols)).to_h { |code, wild, excluded| [ code, [ wild, Array(excluded) ] ] }

      gone = (was.keys - now.keys).map { |code| change(:game, "Symbol #{code}", "removed") }
      new = (now.keys - was.keys).map { |code| change(:game, "Symbol #{code}", "added") }
      altered = (was.keys & now.keys).filter_map do |code|
        wild_before, excluded_before = was[code]
        wild_after, excluded_after = now[code]

        next change(:game, "Symbol #{code}", wild_after ? "is now wild" : "is no longer wild") if wild_before != wild_after
        next unless excluded_before != excluded_after

        change(:game, "Symbol #{code}", "substitutions changed")
      end

      gone + new + altered
    end

    def groups
      was = Array(before(:groups)).to_h { |name, members| [ name, Array(members) ] }
      now = Array(after(:groups)).to_h { |name, members| [ name, Array(members) ] }

      gone = (was.keys - now.keys).map { |name| change(:game, "Group #{name}", "removed") }
      new = (now.keys - was.keys).map { |name| change(:game, "Group #{name}", "added") }
      altered = (was.keys & now.keys).filter_map do |name|
        change(:game, "Group #{name}", "#{was[name].join(" ")} → #{now[name].join(" ")}") if was[name] != now[name]
      end

      gone + new + altered
    end

    def window
      [].tap do |found|
        if before(:window) != after(:window)
          found << change(:game, "Reel window", "#{Array(before(:window)).join("×")} → #{Array(after(:window)).join("×")}")
        end

        if before(:mechanic) != after(:mechanic)
          found << change(:game, "Win mechanic", "#{before(:mechanic)} → #{after(:mechanic)}")
        end
      end
    end
end
