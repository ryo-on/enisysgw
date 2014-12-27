class CreateAccessLogs < ActiveRecord::Migration
  def self.up
    create_table :access_logs, :id => false, :force => true do |t|
      t.integer :user_id
      t.string :user_code, :limit => 255
      t.string :user_name, :limit => 255
      t.string :controller_name, :limit => 255
      t.string :action_name, :limit => 255
      t.text :parameters
      t.string :feature_id, :limit => 255
      t.string :feature_name, :limit => 255
      t.string :ipaddress, :limit => 255
      t.datetime :created_at
      t.datetime :updated_at
    end
  end

  def self.down
    drop_table :access_logs
  end
end
