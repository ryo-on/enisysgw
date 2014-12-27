class CreateGwReminders < ActiveRecord::Migration
  def change
    create_table :gw_reminders do |t|
      t.integer :user_id
      t.string :category
      t.string :sub_category
      t.integer :title_id
      t.integer :item_id
      t.string :title
      t.datetime :datetime
      t.string :url
      t.string :action
      t.datetime :seen_at

      t.timestamps
    end
  end
end
