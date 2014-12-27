class CreateGwPropAdminSettingRoles < ActiveRecord::Migration
  def self.up
    create_table :gw_prop_admin_setting_roles, :force => true do |t|
      t.integer :prop_setting_id
      t.integer :gid
      t.datetime :created_at
      t.datetime :updated_at
    end
  end

  def self.down
    drop_table :gw_prop_admin_setting_roles
  end
end
