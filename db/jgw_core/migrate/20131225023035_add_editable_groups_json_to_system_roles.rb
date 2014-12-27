class AddEditableGroupsJsonToSystemRoles < ActiveRecord::Migration
  def change
    add_column :system_roles, :editable_groups_json, :text
  end
end
