class CreateConfigScripts < ActiveRecord::Migration[6.0]
  def change
    create_table :config_scripts do |t|
      t.string :script_name
    end
  end
end
