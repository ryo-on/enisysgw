class AddSpecConfigToGwCircularDocs < ActiveRecord::Migration
  def change
    add_column :gwcircular_docs, :spec_config, :integer
  end
end
