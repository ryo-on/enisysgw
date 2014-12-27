class CreateGwPropAdminSettings < ActiveRecord::Migration
  def self.up
    create_table :gw_prop_admin_settings, :force => true do |t|
      t.string :name, :limit => 255
      t.integer :type_id
      t.integer :span
      t.integer :span_limit
      t.integer :span_hour
      t.integer :span_min
      t.integer :time_limit
      t.datetime :created_at
      t.datetime :updated_at
    end
  end

  def self.down
    drop_table :gw_prop_admin_settings
  end
end
