class AddSortNoToSystemUsers < ActiveRecord::Migration
  def change
    add_column :system_users, :sort_no, :integer
  end
end
