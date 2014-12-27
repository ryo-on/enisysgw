class AddCategoryToSystemGroups < ActiveRecord::Migration
  def change
    add_column :system_groups, :category, :integer
  end
end
