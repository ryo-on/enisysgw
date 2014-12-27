class AddIndexesToGwReminders < ActiveRecord::Migration
  def change
    add_index :gw_reminders, :user_id
  end
end
