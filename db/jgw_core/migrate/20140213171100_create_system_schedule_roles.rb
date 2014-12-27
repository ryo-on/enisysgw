class CreateSystemScheduleRoles < ActiveRecord::Migration
  def self.up
    create_table :system_schedule_roles, :force => true do |t|
      t.integer :target_uid, :null => false
      t.integer :user_id
      t.integer :group_id
      t.datetime :created_at
      t.datetime :updated_at
    end
  end

  def self.down
    drop_table :system_schedule_roles
  end
end
