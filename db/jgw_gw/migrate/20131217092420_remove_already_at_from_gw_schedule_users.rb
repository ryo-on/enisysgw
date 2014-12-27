class RemoveAlreadyAtFromGwScheduleUsers < ActiveRecord::Migration
  def self.up
    remove_column :gw_schedule_users, :already_at
  end

  def self.down
    add_column :gw_schedule_users, :already_at, :datetime
  end

end
