class CreateGwPropGroups < ActiveRecord::Migration
  def self.up
    create_table :gw_prop_groups, :force => true do |t|
      t.text :state
      t.string :name, :limit => 255
      t.integer :sort_no
      t.integer :parent_id
      t.datetime :created_at
      t.datetime :updated_at
      t.datetime :deleted_at
    end
    execute "insert into gw_prop_groups values(1,'public','(root)',0,1,now(),now(),null)"
  end

  def self.down
    drop_table :gw_prop_groups
  end
end
