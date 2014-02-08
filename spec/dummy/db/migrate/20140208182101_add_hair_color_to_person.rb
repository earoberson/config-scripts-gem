class AddHairColorToPerson < ActiveRecord::Migration
  def change
    add_column :people, :hair_color_id, :integer
    add_index :people, :hair_color_id
  end
end
