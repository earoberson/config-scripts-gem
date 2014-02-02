class CreateConfigScripts < ActiveRecord::Migration
  def change
    create_table :config_scripts do |t|
      t.string :name
    end
  end
end
