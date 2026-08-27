# The symbols a spin put on screen: one column per reel, ordered by the game's rows.
#
# Built by hand for now. When evaluation exists it will produce these from a stop
# position per reel; nothing about the mechanics depends on where the window came from.
class ReelWindow
  def initialize(game, columns)
    @game = game
    @columns = columns
  end

  # The symbol on a reel at a centred row index.
  def at(reel, row)
    @columns[reel]&.[](@game.offset_from_top(row))
  end

  # How many positions on this reel satisfy a matcher, counting wilds that stand in.
  # This is the multiplicity a ways game multiplies together.
  def matches_for(reel, matcher)
    Array(@columns[reel]).count { |shown| matcher.matches?(shown) }
  end
end
