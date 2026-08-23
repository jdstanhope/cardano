# The standard payline shapes for a window, and the sets a game can apply.
#
# Lines are generated rather than transcribed. Transcribing "the standard twenty" from
# memory is how a mistyped payline gets in, and a mistyped payline is still a valid
# payline — it produces a plausible RTP rather than an error. Generating them from
# stated rules means the rules are what gets reviewed.
#
# Two rules produce the shapes:
#
#   Adjacency — a line moves at most one row between neighbouring reels, so it stays a
#   line rather than jumping across the window.
#
#   Mirroring — a line's vertical mirror is also a line, and the two sit together in
#   the order. Sets are therefore closed under mirroring.
#
# Closure has a consequence worth knowing: on a window with a centre row, the only
# line that is its own mirror is the centre line, so a closed set always has an odd
# size. Twenty is not available for that reason. A twenty line game is the twenty-five
# set with five lines removed, which is how real sets are built anyway.
class PaylineCatalogue
  SET_SIZES = [ 1, 5, 9, 15, 25 ].freeze

  # The conventional opening of a five reel, three row set, written down rather than
  # derived. Generation gets the shapes right but not the order: a single step off the
  # centre is smoother than the diagonal, so a derived order puts trivial shapes ahead
  # of the lines every real game opens with.
  #
  # These nine are the ones a five and a nine line game use, in the order they are
  # normally numbered — centre, the two horizontals, the two diagonals, the V and its
  # inverse, then the two arches. Each is followed by its mirror.
  #
  # Reviewable as data. Everything after them comes from the generated order.
  CONVENTIONAL_OPENINGS = {
    [ 5, 3 ] => [
      [  0,  0,  0,  0,  0 ],
      [  1,  1,  1,  1,  1 ],
      [ -1, -1, -1, -1, -1 ],
      [  1,  1,  0, -1, -1 ],
      [ -1, -1,  0,  1,  1 ],
      [  1,  0, -1,  0,  1 ],
      [ -1,  0,  1,  0, -1 ],
      [  0,  1,  1,  1,  0 ],
      [  0, -1, -1, -1,  0 ]
    ]
  }.freeze

  def initialize(game)
    @game = game
  end

  def sets
    SET_SIZES.select { |size| size <= shapes.length }.map { |size| Set.new(size, shapes.first(size)) }
  end

  def shapes = @shapes ||= ordered_shapes

  Set = Struct.new(:size, :rows) do
    def label = size == 1 ? "1 line" : "#{size} lines"
  end

  private
    attr_reader :game

    # Centre first, then each line beside its mirror. Within that, lines that stay
    # closer to the centre come first, so the flat and gently sloping shapes arrive
    # before the ones that cross the whole window.
    def ordered_shapes
      opening = CONVENTIONAL_OPENINGS.fetch([ game.reel_count, game.row_count ], [])
      paired = adjacent_paths.group_by { |path| canonical(path) }.values

      generated = paired.sort_by { |group| [ wander(group.first), group.first.map(&:-@) ] }
                        .flat_map { |group| group.sort_by { |path| -path.sum } }

      opening + (generated - opening)
    end

    # A line and its mirror share a key, so they land together.
    def canonical(path)
      mirrored = path.map(&:-@)

      [ path, mirrored ].min
    end

    # Smoothness first, then how far the line strays from the centre. A payline is a
    # shape across the window, so the flat and gently sloping ones come before the
    # ones that zigzag — which puts the horizontals at 2 and 3 and the diagonals next,
    # the order real sets are built in.
    def wander(path)
      [ path.each_cons(2).sum { |a, b| (a - b).abs }, path.sum(&:abs) ]
    end

    def adjacent_paths
      game.row_indices.map { |row| [ row ] }.then do |paths|
        (game.reel_count - 1).times do
          paths = paths.flat_map do |path|
            game.row_indices.select { |row| (row - path.last).abs <= 1 }.map { |row| path + [ row ] }
          end
        end

        paths
      end
    end
end
