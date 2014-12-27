class AddIndexesToAccessLogs < ActiveRecord::Migration
  def change
    add_index :access_logs, :created_at
  end
end
