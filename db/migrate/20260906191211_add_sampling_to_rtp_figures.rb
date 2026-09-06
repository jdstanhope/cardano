class AddSamplingToRtpFigures < ActiveRecord::Migration[8.1]
  def change
    # What a sampled figure needs beyond the figure itself. All nullable: an exact figure
    # has none of these, and that absence is the honest record of how it was arrived at
    # rather than a gap to be filled in.
    #
    # The half width is what the figure might be out by, and the confidence is how sure
    # that claim is; neither means anything without the other. Coverage is how often each
    # combination actually landed, which is what says whether an interval computed before
    # a rare combination fell should be believed.
    add_column :rtp_figures, :half_width, :decimal
    add_column :rtp_figures, :confidence, :integer
    add_column :rtp_figures, :spins, :bigint
    add_column :rtp_figures, :coverage, :jsonb
  end
end
