require "test_helper"

class PaylineCatalogueTest < ActiveSupport::TestCase
  setup do
    @game = games(:five_by_three)
    @catalogue = PaylineCatalogue.new(@game)
  end

  test "every shape fits the window it was made for" do
    @catalogue.shapes.each do |shape|
      assert_equal @game.reel_count, shape.length
      shape.each { |row| assert @game.row_range.cover?(row), "#{shape.inspect} leaves the window" }
    end
  end

  test "no shape is offered twice" do
    assert_equal @catalogue.shapes.length, @catalogue.shapes.uniq.length
  end

  test "a line never jumps more than one row between neighbouring reels" do
    @catalogue.shapes.each do |shape|
      shape.each_cons(2) do |a, b|
        assert_operator (a - b).abs, :<=, 1, "#{shape.inspect} jumps across the window"
      end
    end
  end

  test "every shape's mirror is also offered" do
    shapes = @catalogue.shapes.to_set

    @catalogue.shapes.each do |shape|
      assert_includes shapes, shape.map(&:-@), "#{shape.inspect} has no mirror"
    end
  end

  test "every offered set is closed under mirroring" do
    @catalogue.sets.each do |set|
      rows = set.rows.to_set

      set.rows.each do |shape|
        assert_includes rows, shape.map(&:-@),
          "the #{set.label} set contains #{shape.inspect} without its mirror"
      end
    end
  end

  test "closed sets have an odd size, which is why twenty is not offered" do
    # On a window with a centre row the only self-mirroring line is the centre line,
    # so a closed set is one line plus mirrored pairs. Twenty cannot be closed.
    assert @catalogue.sets.map(&:size).all?(&:odd?)
    assert_not_includes @catalogue.sets.map(&:size), 20
  end

  test "the conventional opening is used where one is written down" do
    assert_equal [ 0, 0, 0, 0, 0 ], @catalogue.shapes[0]
    assert_equal [ 1, 1, 1, 1, 1 ], @catalogue.shapes[1]
    assert_equal [ -1, -1, -1, -1, -1 ], @catalogue.shapes[2]
    assert_equal [ 1, 1, 0, -1, -1 ], @catalogue.shapes[3], "the diagonal is line four"
    assert_equal [ 1, 0, -1, 0, 1 ], @catalogue.shapes[5], "the V is line six"
  end

  test "a window with no written convention still produces valid shapes" do
    unusual = Game.new(reel_count: 3, row_count: 3)
    shapes = PaylineCatalogue.new(unusual).shapes

    assert_predicate shapes, :any?
    assert_equal [ 0, 0, 0 ], shapes.first
    shapes.each { |shape| assert_equal 3, shape.length }
  end

  test "sets are prefixes of one another, so a smaller set is contained in a larger" do
    sets = @catalogue.sets

    sets.each_cons(2) do |smaller, larger|
      assert_equal smaller.rows, larger.rows.first(smaller.size)
    end
  end
end
