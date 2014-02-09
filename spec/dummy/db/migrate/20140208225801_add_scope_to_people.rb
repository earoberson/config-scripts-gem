class AddScopeToPeople < ActiveRecord::Migration
  def change
    add_column :people, :scope_type, :string
    add_column :people, :scope_id, :integer
  end
end
