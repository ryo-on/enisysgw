class RemoveSortNoFromSystemUsers < ActiveRecord::Migration
  def up
    remove_column :system_users, :sort_no
  end

  def down
    add_column :system_users, :sort_no, :string
  end
end
