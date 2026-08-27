# Picks a name nobody in the account is already using.
#
# Game names are unique per account, so anything that creates a game on somebody's
# behalf — duplicating one, copying a sample — has to cope with the obvious name being
# taken. Numbering from the first collision keeps the common case readable and the
# repeated case possible.
module GameName
  def self.free_for(user, base)
    return base unless taken?(user, base)

    (2..).lazy.map { |n| "#{base} #{n}" }.reject { |candidate| taken?(user, candidate) }.first
  end

  def self.taken?(user, candidate) = user.games.exists?(name: candidate)
end
