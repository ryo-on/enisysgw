class AddAdminRolesToDoclibraryFolders < ActiveRecord::Migration
  def change
    add_column :doclibrary_folders, :admins, :text
    add_column :doclibrary_folders, :admins_json, :text
    add_column :doclibrary_folders, :admin_groups, :text
    add_column :doclibrary_folders, :admin_groups_json, :text
  end
end
