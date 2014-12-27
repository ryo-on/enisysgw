class AddLocationToGwEditLinkPieces < ActiveRecord::Migration
  def change
    add_column :gw_edit_link_pieces, :location, :integer
  end
end
