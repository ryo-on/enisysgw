class AddDetailsToGwScheduleUsers < ActiveRecord::Migration
  def self.up
    add_column :gw_schedule_users, :already_at, :datetime
  end

  def self.down
    remove_column :gw_schedule_users, :already_at
  end
end
