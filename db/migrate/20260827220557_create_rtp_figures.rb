class CreateRtpFigures < ActiveRecord::Migration[8.1]
  def change
    create_table :rtp_figures do |t|
      t.references :variation, null: false, foreign_key: true

      # The figure as the exact fraction it was computed as. Storing a rounded decimal
      # would throw away the thing evaluating every outcome was for, and two figures
      # that differ in the twelfth place would compare as equal.
      t.decimal :numerator, null: false
      t.decimal :denominator, null: false

      t.string :computed_by, null: false
      t.string :fingerprint, null: false

      t.timestamps
    end

    # Reading a variation's figures means "the most recent few, newest first".
    add_index :rtp_figures, [ :variation_id, :created_at ]
  end
end
