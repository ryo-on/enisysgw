class AddColumnToGwPropOthers < ActiveRecord::Migration
  def change
    add_column :gw_prop_others, :d_load_st, :datetime
    add_column :gw_prop_others, :d_load_ed, :datetime
  end
end
