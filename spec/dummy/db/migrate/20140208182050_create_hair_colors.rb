class CreateHairColors < ActiveRecord::Migration[4.2]
  def change
    create_table :hair_colors do |t|
      t.string :color

      t.timestamps
    end
  end
end
