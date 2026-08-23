# A symbol the wild does not substitute for.
#
# A deny list rather than an allow list: a wild substitutes for everything except what
# is named here. A symbol added later is therefore substitutable without anyone
# remembering to update anything, which is almost always what is wanted. An allow list
# would silently exclude it, producing an RTP that is too low while looking reasonable.
class WildExclusion < ApplicationRecord
  belongs_to :wild, class_name: "GameSymbol"
  belongs_to :excluded, class_name: "GameSymbol"

  validates :excluded_id, uniqueness: { scope: :wild_id }

  validate :only_a_wild_excludes
  validate :cannot_exclude_itself
  validate :both_belong_to_one_game

  private
    def only_a_wild_excludes
      return if wild.nil? || wild.wild?

      errors.add(:wild, "is not a wild, so it substitutes for nothing")
    end

    def cannot_exclude_itself
      return if wild.nil? || excluded.nil? || wild != excluded

      errors.add(:excluded, "is the wild itself, which never substitutes for itself")
    end

    def both_belong_to_one_game
      return if wild.nil? || excluded.nil? || wild.game_id == excluded.game_id

      errors.add(:excluded, "belongs to a different game")
    end
end
