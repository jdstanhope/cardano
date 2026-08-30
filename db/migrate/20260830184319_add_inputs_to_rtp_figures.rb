class AddInputsToRtpFigures < ActiveRecord::Migration[8.1]
  def change
    # The description the figure was computed from, not only a hash of it.
    #
    # The fingerprint can say a change happened; only the inputs themselves can say
    # what changed, and only they can be put back. Stored as the canonical structure
    # RtpFingerprint already builds, so the hash and the snapshot cannot disagree.
    #
    # Nullable: figures recorded before this column existed have no snapshot, and a
    # history that quietly invented one for them would be lying about what is known.
    add_column :rtp_figures, :inputs, :jsonb
  end
end
