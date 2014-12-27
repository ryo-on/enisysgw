class AddDeleteStateToGwSchedules < ActiveRecord::Migration
  def self.up
    add_column :gw_schedules, :delete_state, :integer, :default => 0
  end

  def self.down
    remove_column :gw_schedules, :delete_state
  end
end
