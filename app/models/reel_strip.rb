class ReelStrip < ApplicationRecord
  belongs_to :variation

  has_one :game, through: :variation

  validates :position, presence: true, uniqueness: { scope: :variation_id }

  validate :position_is_a_reel_the_game_has
  validate :has_at_least_one_stop
  validate :stops_are_symbols_of_the_game

  # Reels may differ in length. That is normal design and a lever on the maths, so
  # nothing here requires strips to match one another.
  def stop_count
    symbols.to_a.length
  end

  private
    def position_is_a_reel_the_game_has
      return if game.nil? || position.nil?
      return if position.between?(1, game.reel_count)

      errors.add(:position, "must be a reel between 1 and #{game.reel_count}")
    end

    def has_at_least_one_stop
      return if symbols.present?

      errors.add(:symbols, "must have at least one stop")
    end

    def stops_are_symbols_of_the_game
      return if game.nil? || symbols.blank?

      unknown = symbols.uniq - game.symbols.pluck(:code)
      return if unknown.empty?

      errors.add(:symbols, "#{unknown.to_sentence} not among the game's symbols")
    end
end
