class CreateConfigScripts < ActiveRecord::Migration[4.2]
  def change
    create_table :config_scripts do |t|
      t.string :script_name
    end
  end
end
