class CreateSystemRoleGroups < ActiveRecord::Migration
  def change
    create_table :system_role_groups do |t|
      t.references :system_role
      t.string :role_code
      t.string :group_code
      t.integer :group_id
      t.text :group_name

      t.timestamps
    end
    add_index :system_role_groups, :system_role_id
  end
end
