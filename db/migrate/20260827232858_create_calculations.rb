class CreateCalculations < ActiveRecord::Migration[8.1]
  def change
    create_table :calculations do |t|
      t.references :variation, null: false, foreign_key: true

      t.string :computed_by, null: false
      t.string :state, null: false

      t.datetime :started_at
      t.datetime :finished_at

      # What it was computed for. A run that finishes after the description moved on
      # produced a figure for something that no longer exists, and has to be able to
      # say so rather than presenting it as current.
      t.string :fingerprint, null: false

      # Set when a run produces one. A run can finish without a figure: cancelled,
      # failed, or asked to describe something incomplete.
      t.references :rtp_figure, foreign_key: true

      t.string :failure

      t.timestamps
    end

    add_index :calculations, [ :variation_id, :created_at ]

    # Finding what is still in flight, which is asked on every render of a variation.
    add_index :calculations, [ :variation_id, :state ]
  end
end
