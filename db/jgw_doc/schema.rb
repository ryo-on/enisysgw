# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20140305083507) do

  create_table "doclibrary_categories", :force => true do |t|
    t.integer  "unid"
    t.integer  "content_id"
    t.text     "state"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "title_id"
    t.integer  "parent_id"
    t.integer  "sort_no"
    t.integer  "level_no"
    t.text     "wareki"
    t.integer  "nen"
    t.integer  "gatsu"
    t.integer  "sono"
    t.integer  "sono2"
    t.string   "filename"
    t.string   "note_id"
    t.text     "createdate"
    t.boolean  "creater_admin"
    t.string   "createrdivision_id", :limit => 20
    t.text     "createrdivision"
    t.string   "creater_id",         :limit => 20
    t.text     "creater"
    t.text     "editdate"
    t.boolean  "editor_admin"
    t.string   "editordivision_id",  :limit => 20
    t.text     "editordivision"
    t.string   "editor_id",          :limit => 20
    t.text     "editor"
  end

  create_table "doclibrary_db_files", :force => true do |t|
    t.integer "title_id"
    t.integer "parent_id"
    t.binary  "data",      :limit => 2147483647
  end

  create_table "doclibrary_docs", :force => true do |t|
    t.integer  "unid"
    t.integer  "content_id"
    t.text     "state"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "recognized_at"
    t.datetime "published_at"
    t.datetime "latest_updated_at"
    t.integer  "doc_type"
    t.integer  "parent_id"
    t.text     "content_state"
    t.string   "section_code"
    t.text     "section_name"
    t.integer  "importance"
    t.integer  "one_line_note"
    t.integer  "title_id"
    t.text     "name"
    t.text     "pname"
    t.text     "title"
    t.text     "head",               :limit => 16777215
    t.text     "body",               :limit => 16777215
    t.text     "note",               :limit => 16777215
    t.integer  "category_use"
    t.integer  "category1_id"
    t.integer  "category2_id"
    t.integer  "category3_id"
    t.integer  "category4_id"
    t.text     "keywords"
    t.text     "createdate"
    t.boolean  "creater_admin"
    t.string   "createrdivision_id", :limit => 20
    t.text     "createrdivision"
    t.string   "creater_id",         :limit => 20
    t.text     "creater"
    t.text     "editdate"
    t.boolean  "editor_admin"
    t.string   "editordivision_id",  :limit => 20
    t.text     "editordivision"
    t.string   "editor_id",          :limit => 20
    t.text     "editor"
    t.datetime "expiry_date"
    t.integer  "attachmentfile"
    t.string   "form_name"
    t.text     "inpfld_001"
    t.integer  "inpfld_002"
    t.integer  "inpfld_003"
    t.integer  "inpfld_004"
    t.integer  "inpfld_005"
    t.integer  "inpfld_006"
    t.text     "inpfld_007"
    t.text     "inpfld_008"
    t.text     "inpfld_009"
    t.text     "inpfld_010"
    t.text     "inpfld_011"
    t.text     "inpfld_012"
    t.text     "notes_001"
    t.text     "notes_002"
    t.text     "notes_003"
  end

  add_index "doclibrary_docs", ["category1_id"], :name => "category1_id"
  add_index "doclibrary_docs", ["state", "title_id", "category1_id"], :name => "title_id", :length => {"state"=>50, "title_id"=>nil, "category1_id"=>nil}
  add_index "doclibrary_docs", ["title_id"], :name => "title_id2"

  create_table "doclibrary_files", :force => true do |t|
    t.integer  "unid"
    t.integer  "content_id"
    t.text     "state"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "recognized_at"
    t.datetime "published_at"
    t.datetime "latest_updated_at"
    t.integer  "parent_id"
    t.integer  "title_id"
    t.string   "content_type"
    t.text     "filename"
    t.text     "memo"
    t.integer  "size"
    t.integer  "width"
    t.integer  "height"
    t.integer  "db_file_id"
  end

  create_table "doclibrary_folder_acls", :force => true do |t|
    t.integer  "unid"
    t.integer  "content_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "folder_id"
    t.integer  "title_id"
    t.integer  "acl_flag"
    t.integer  "acl_section_id"
    t.string   "acl_section_code"
    t.text     "acl_section_name"
    t.integer  "acl_user_id"
    t.string   "acl_user_code"
    t.text     "acl_user_name"
  end

  add_index "doclibrary_folder_acls", ["acl_section_code"], :name => "acl_section_code"
  add_index "doclibrary_folder_acls", ["acl_user_code"], :name => "acl_user_code"
  add_index "doclibrary_folder_acls", ["folder_id"], :name => "folder_id"
  add_index "doclibrary_folder_acls", ["title_id"], :name => "title_id"

  create_table "doclibrary_folders", :force => true do |t|
    t.integer  "unid"
    t.integer  "parent_id"
    t.text     "state"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "title_id"
    t.integer  "sort_no"
    t.integer  "level_no"
    t.integer  "children_size"
    t.integer  "total_children_size"
    t.text     "name"
    t.text     "memo"
    t.text     "readers"
    t.text     "readers_json"
    t.text     "reader_groups"
    t.text     "reader_groups_json"
    t.datetime "docs_last_updated_at"
    t.text     "admins"
    t.text     "admins_json"
    t.text     "admin_groups"
    t.text     "admin_groups_json"
  end

  add_index "doclibrary_folders", ["parent_id"], :name => "parent_id"
  add_index "doclibrary_folders", ["sort_no"], :name => "sort_no"
  add_index "doclibrary_folders", ["title_id"], :name => "title_id"

  create_table "doclibrary_group_folders", :force => true do |t|
    t.integer  "unid"
    t.integer  "parent_id"
    t.text     "state"
    t.text     "use_state"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "title_id"
    t.integer  "sort_no"
    t.integer  "level_no"
    t.integer  "children_size"
    t.integer  "total_children_size"
    t.string   "code"
    t.text     "name"
    t.integer  "sysgroup_id"
    t.integer  "sysparent_id"
    t.text     "readers"
    t.text     "readers_json"
    t.text     "reader_groups"
    t.text     "reader_groups_json"
    t.datetime "docs_last_updated_at"
  end

  add_index "doclibrary_group_folders", ["code"], :name => "code"

  create_table "doclibrary_recognizers", :force => true do |t|
    t.integer  "unid"
    t.datetime "updated_at"
    t.datetime "created_at"
    t.integer  "title_id"
    t.integer  "parent_id"
    t.integer  "user_id"
    t.string   "code"
    t.text     "name"
    t.datetime "recognized_at"
  end

  create_table "doclibrary_view_acl_doc_counts", :id => false, :force => true do |t|
    t.text    "state"
    t.integer "title_id"
    t.integer "acl_flag"
    t.string  "acl_section_code"
    t.string  "acl_user_code"
    t.string  "section_code"
    t.integer "cnt",              :limit => 8, :default => 0, :null => false
  end

  create_table "doclibrary_view_acl_docs", :id => false, :force => true do |t|
    t.integer "id",               :default => 0, :null => false
    t.integer "sort_no"
    t.integer "acl_flag"
    t.integer "acl_section_id"
    t.string  "acl_section_code"
    t.text    "acl_section_name"
    t.integer "acl_user_id"
    t.string  "acl_user_code"
    t.text    "acl_user_name"
    t.text    "folder_name"
  end

  create_table "doclibrary_view_acl_files", :id => false, :force => true do |t|
    t.text     "docs_state"
    t.integer  "id",                :default => 0, :null => false
    t.integer  "unid"
    t.integer  "content_id"
    t.text     "state"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "recognized_at"
    t.datetime "published_at"
    t.datetime "latest_updated_at"
    t.integer  "parent_id"
    t.integer  "title_id"
    t.string   "content_type"
    t.text     "filename"
    t.text     "memo"
    t.integer  "size"
    t.integer  "width"
    t.integer  "height"
    t.integer  "db_file_id"
    t.integer  "category1_id"
    t.string   "section_code"
    t.integer  "acl_flag"
    t.integer  "acl_section_id"
    t.string   "acl_section_code"
    t.text     "acl_section_name"
    t.integer  "acl_user_id"
    t.string   "acl_user_code"
    t.text     "acl_user_name"
  end

  create_table "doclibrary_view_acl_folders", :id => false, :force => true do |t|
    t.integer  "id",                   :default => 0, :null => false
    t.integer  "unid"
    t.integer  "parent_id"
    t.text     "state"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "title_id"
    t.integer  "sort_no"
    t.integer  "level_no"
    t.integer  "children_size"
    t.integer  "total_children_size"
    t.text     "name"
    t.text     "memo"
    t.text     "admins"
    t.text     "admins_json"
    t.text     "admin_groups"
    t.text     "admin_groups_json"
    t.text     "readers"
    t.text     "readers_json"
    t.text     "reader_groups"
    t.text     "reader_groups_json"
    t.datetime "docs_last_updated_at"
    t.integer  "acl_flag"
    t.integer  "acl_section_id"
    t.string   "acl_section_code"
    t.text     "acl_section_name"
    t.integer  "acl_user_id"
    t.string   "acl_user_code"
    t.text     "acl_user_name"
  end

end
