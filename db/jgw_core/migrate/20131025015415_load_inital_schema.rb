class LoadInitalSchema < ActiveRecord::Migration
  def change
    load Rails.root.join('db', 'jgw_core', 'inital_schema.rb').to_s
  end
end
