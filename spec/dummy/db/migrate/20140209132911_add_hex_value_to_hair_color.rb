class AddHexValueToHairColor < ActiveRecord::Migration[4.2]
  def change
    add_column :hair_colors, :hex_value, :string
  end
end
