class AddCategoryToSystemUsersGroupsCsvdata < ActiveRecord::Migration
  def change
    add_column :system_users_groups_csvdata, :category, :integer
  end
end
