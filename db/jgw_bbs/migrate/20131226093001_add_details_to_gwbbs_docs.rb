class AddDetailsToGwbbsDocs < ActiveRecord::Migration
  def self.up
    add_column :gwbbs_docs, :name_type, :integer
    add_column :gwbbs_docs, :name_creater_section_id, :string, :limit => 20
    add_column :gwbbs_docs, :name_creater_section, :text
    add_column :gwbbs_docs, :name_editor_section_id, :string, :limit => 20
    add_column :gwbbs_docs, :name_editor_section, :text
  end

  def self.down
    remove_column :gwbbs_docs, :name_type
    remove_column :gwbbs_docs, :name_creater_section_id
    remove_column :gwbbs_docs, :name_creater_section
    remove_column :gwbbs_docs, :name_editor_section_id
    remove_column :gwbbs_docs, :name_editor_section
  end
end
