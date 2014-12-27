class AddLimitMonthToGwPropOthers < ActiveRecord::Migration
  def change
    add_column :gw_prop_others, :limit_month, :integer
  end
end
