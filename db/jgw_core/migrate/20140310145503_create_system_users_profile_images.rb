class CreateSystemUsersProfileImages < ActiveRecord::Migration
  def change
    create_table :system_users_profile_images do |t|
      t.integer :user_id
      t.string :user_code
      t.string :note
      t.string :path
      t.string :orig_filename
      t.string :content_type

      t.timestamps
    end
  end
end
