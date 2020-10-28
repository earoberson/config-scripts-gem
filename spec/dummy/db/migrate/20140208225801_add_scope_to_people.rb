class AddScopeToPeople < ActiveRecord::Migration[4.2]
  def change
    add_column :people, :scope_type, :string
    add_column :people, :scope_id, :integer
  end
end
