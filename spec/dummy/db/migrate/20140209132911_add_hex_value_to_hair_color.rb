class AddHexValueToHairColor < ActiveRecord::Migration
  def change
    add_column :hair_colors, :hex_value, :string
  end
end
