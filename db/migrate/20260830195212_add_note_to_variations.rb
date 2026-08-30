class AddNoteToVariations < ActiveRecord::Migration[8.1]
  def change
    # What this variation is for, in the designer's words. Written by branching to say
    # where it came from, and theirs to change afterwards — a variation exists for a
    # reason only the person designing it knows.
    add_column :variations, :note, :text
  end
end
