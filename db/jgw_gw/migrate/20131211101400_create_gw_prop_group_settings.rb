class CreateGwPropGroupSettings < ActiveRecord::Migration
  def self.up
    create_table :gw_prop_group_settings, :force => true do |t|
      t.integer :prop_group_id
      t.integer :prop_other_id
      t.datetime :created_at
      t.datetime :updated_at
    end
  end

  def self.down
    drop_table :gw_prop_group_settings
  end
end
