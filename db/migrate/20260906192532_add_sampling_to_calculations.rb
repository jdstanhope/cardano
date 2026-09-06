class AddSamplingToCalculations < ActiveRecord::Migration[8.1]
  def change
    # What a run needs to be a simulation. All nullable: an exact run has none of them.
    #
    # The seed is the important one. A figure somebody disputes is exactly the case this
    # has to serve, and a figure that cannot be recomputed to the same number cannot be
    # investigated at all.
    #
    # The precision is in basis points, the unit a variation's target band already uses:
    # +/-0.05 points is 5. Two units for the same kind of quantity is how they get swapped.
    add_column :calculations, :seed, :bigint
    add_column :calculations, :spins, :bigint
    add_column :calculations, :precision_points, :integer
    add_column :calculations, :confidence, :integer
    add_column :calculations, :ceiling, :bigint
    add_column :calculations, :stopped_because, :string
  end
end
