class CreateSystemUsersProfiles < ActiveRecord::Migration
  def change
    create_table :system_users_profiles do |t|
      t.integer :user_id
      t.string :user_code
      t.text :add_column1
      t.text :add_column2
      t.text :add_column3
      t.text :add_column4
      t.text :add_column5

      t.timestamps
    end
  end
end
