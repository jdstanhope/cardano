class Payline < ApplicationRecord
  belongs_to :game

  validates :position, presence: true, uniqueness: { scope: :game_id }

  validate :takes_one_row_per_reel
  validate :rows_exist_in_the_window

  private
    def takes_one_row_per_reel
      return if game.nil? || rows.nil?
      return if rows.length == game.reel_count

      errors.add(:rows, "must give one row per reel (#{game.reel_count})")
    end

    def rows_exist_in_the_window
      return if game.nil? || rows.nil?

      outside = rows.reject { |row| game.row_range.cover?(row) }.uniq
      return if outside.empty?

      errors.add(:rows, "#{outside.to_sentence} outside the window (#{game.row_range})")
    end
end
