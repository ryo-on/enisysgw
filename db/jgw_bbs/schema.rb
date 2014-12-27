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

ActiveRecord::Schema.define(:version => 20131226093001) do

  create_table "gwbbs_categories", :force => true do |t|
    t.integer  "unid"
    t.integer  "parent_id"
    t.text     "state"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "title_id"
    t.integer  "sort_no"
    t.integer  "level_no"
    t.text     "name"
  end

  create_table "gwbbs_comments", :force => true do |t|
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
    t.integer  "title_id"
    t.text     "name"
    t.text     "pname"
    t.text     "title"
    t.text     "head",               :limit => 16777215
    t.text     "body",               :limit => 16777215
    t.text     "note",               :limit => 16777215
    t.integer  "category1_id"
    t.integer  "category2_id"
    t.integer  "category3_id"
    t.integer  "category4_id"
    t.text     "keyword1"
    t.text     "keyword2"
    t.text     "keyword3"
    t.text     "keywords"
    t.text     "createdate"
    t.string   "createrdivision_id", :limit => 20
    t.text     "createrdivision"
    t.string   "creater_id",         :limit => 20
    t.text     "creater"
    t.text     "editdate"
    t.string   "editordivision_id",  :limit => 20
    t.text     "editordivision"
    t.string   "editor_id",          :limit => 20
    t.text     "editor"
    t.datetime "expiry_date"
    t.text     "inpfld_001"
    t.text     "inpfld_002"
  end

  create_table "gwbbs_db_files", :force => true do |t|
    t.integer "title_id"
    t.integer "parent_id"
    t.binary  "data",      :limit => 2147483647
  end

  create_table "gwbbs_docs", :force => true do |t|
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
    t.text     "head",                    :limit => 16777215
    t.text     "body",                    :limit => 16777215
    t.text     "note",                    :limit => 16777215
    t.integer  "category_use"
    t.integer  "category1_id"
    t.integer  "category2_id"
    t.integer  "category3_id"
    t.integer  "category4_id"
    t.text     "keywords"
    t.text     "createdate"
    t.boolean  "creater_admin"
    t.string   "createrdivision_id",      :limit => 20
    t.text     "createrdivision"
    t.string   "creater_id",              :limit => 20
    t.text     "creater"
    t.text     "editdate"
    t.boolean  "editor_admin"
    t.string   "editordivision_id",       :limit => 20
    t.text     "editordivision"
    t.string   "editor_id",               :limit => 20
    t.text     "editor"
    t.datetime "able_date"
    t.datetime "expiry_date"
    t.integer  "attachmentfile"
    t.string   "form_name"
    t.text     "inpfld_001"
    t.text     "inpfld_002"
    t.text     "inpfld_003"
    t.text     "inpfld_004"
    t.text     "inpfld_005"
    t.text     "inpfld_006"
    t.string   "inpfld_006w"
    t.datetime "inpfld_006d"
    t.text     "inpfld_007"
    t.text     "inpfld_008"
    t.text     "inpfld_009"
    t.text     "inpfld_010"
    t.text     "inpfld_011"
    t.text     "inpfld_012"
    t.text     "inpfld_013"
    t.text     "inpfld_014"
    t.text     "inpfld_015"
    t.text     "inpfld_016"
    t.text     "inpfld_017"
    t.text     "inpfld_018"
    t.text     "inpfld_019"
    t.text     "inpfld_020"
    t.text     "inpfld_021"
    t.text     "inpfld_022"
    t.text     "inpfld_023"
    t.text     "inpfld_024"
    t.text     "inpfld_025"
    t.integer  "name_type"
    t.string   "name_creater_section_id", :limit => 20
    t.text     "name_creater_section"
    t.string   "name_editor_section_id",  :limit => 20
    t.text     "name_editor_section"
  end

  create_table "gwbbs_files", :force => true do |t|
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

  create_table "gwbbs_recognizers", :force => true do |t|
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

end
