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

ActiveRecord::Schema.define(:version => 0) do

  create_table "intra_maintenances", :force => true do |t|
    t.integer  "unid"
    t.text     "state"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "published_at"
    t.text     "title"
    t.text     "body"
  end

  create_table "intra_messages", :force => true do |t|
    t.integer  "unid"
    t.text     "state"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "published_at"
    t.text     "title"
    t.text     "body"
  end

  create_table "sessions", :force => true do |t|
    t.string   "session_id", :null => false
    t.text     "data"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "sessions", ["session_id"], :name => "index_sessions_on_session_id"
  add_index "sessions", ["updated_at"], :name => "index_sessions_on_updated_at"

  create_table "system_admin_logs", :force => true do |t|
    t.datetime "created_at"
    t.integer  "user_id"
    t.integer  "item_unid"
    t.text     "controller"
    t.text     "action"
  end

  create_table "system_authorizations", :id => false, :force => true do |t|
    t.integer  "user_id",                   :default => 0, :null => false
    t.string   "user_code",                                :null => false
    t.text     "user_name"
    t.text     "user_name_en"
    t.text     "user_password"
    t.text     "user_email"
    t.text     "remember_token"
    t.datetime "remember_token_expires_at"
    t.integer  "group_id",                  :default => 0, :null => false
    t.string   "group_code"
    t.text     "group_name"
    t.text     "group_name_en"
    t.text     "group_email"
  end

  create_table "system_commitments", :force => true do |t|
    t.integer  "unid"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "version"
    t.text     "name"
    t.text     "value",      :limit => 2147483647
  end

  create_table "system_creators", :force => true do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "unid"
    t.integer  "user_id",    :null => false
    t.integer  "group_id",   :null => false
  end

  create_table "system_custom_group_roles", :primary_key => "rid", :force => true do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "group_id"
    t.integer  "custom_group_id"
    t.text     "priv_name"
    t.integer  "user_id"
    t.integer  "class_id"
  end

  add_index "system_custom_group_roles", ["custom_group_id"], :name => "custom_group_id"
  add_index "system_custom_group_roles", ["group_id"], :name => "group_id"
  add_index "system_custom_group_roles", ["user_id"], :name => "user_id"

  create_table "system_custom_groups", :force => true do |t|
    t.integer  "parent_id"
    t.integer  "class_id"
    t.integer  "owner_uid"
    t.integer  "owner_gid"
    t.integer  "updater_uid", :null => false
    t.integer  "updater_gid", :null => false
    t.text     "state"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "level_no"
    t.text     "name"
    t.text     "name_en"
    t.integer  "sort_no"
    t.text     "sort_prefix"
    t.integer  "is_default"
  end

  create_table "system_group_change_pickups", :force => true do |t|
    t.datetime "target_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "system_group_changes", :force => true do |t|
    t.text     "state"
    t.datetime "target_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "system_group_histories", :force => true do |t|
    t.integer  "parent_id"
    t.text     "state"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "level_no"
    t.integer  "version_id"
    t.string   "code"
    t.text     "name"
    t.text     "name_en"
    t.text     "email"
    t.datetime "start_at"
    t.datetime "end_at"
    t.integer  "sort_no"
    t.string   "ldap_version"
    t.integer  "ldap"
  end

  create_table "system_group_history_temporaries", :force => true do |t|
    t.integer  "parent_id"
    t.text     "state"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "level_no"
    t.integer  "version_id"
    t.string   "code"
    t.text     "name"
    t.text     "name_en"
    t.text     "email"
    t.datetime "start_at"
    t.datetime "end_at"
    t.integer  "sort_no"
    t.string   "ldap_version"
    t.integer  "ldap"
  end

  create_table "system_group_nexts", :force => true do |t|
    t.integer  "group_update_id"
    t.text     "operation"
    t.integer  "old_group_id"
    t.text     "old_code"
    t.text     "old_name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "old_parent_id"
  end

  create_table "system_group_temporaries", :force => true do |t|
    t.integer  "parent_id"
    t.text     "state"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "level_no"
    t.integer  "version_id"
    t.string   "code"
    t.text     "name"
    t.text     "name_en"
    t.text     "email"
    t.datetime "start_at"
    t.datetime "end_at"
    t.integer  "sort_no"
    t.string   "ldap_version"
    t.integer  "ldap"
  end

  create_table "system_group_updates", :force => true do |t|
    t.text     "parent_code"
    t.text     "parent_name"
    t.integer  "level_no"
    t.text     "code"
    t.text     "name"
    t.text     "state"
    t.datetime "start_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "group_id"
    t.integer  "parent_id"
  end

  create_table "system_group_versions", :force => true do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "version"
    t.datetime "start_at"
  end

  create_table "system_groups", :force => true do |t|
    t.integer  "parent_id"
    t.text     "state"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "level_no"
    t.integer  "version_id"
    t.string   "code"
    t.text     "name"
    t.text     "name_en"
    t.text     "email"
    t.datetime "start_at"
    t.datetime "end_at"
    t.integer  "sort_no"
    t.string   "ldap_version"
    t.integer  "ldap"
  end

  create_table "system_idconversions", :force => true do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "tablename"
    t.string   "modelname"
    t.datetime "converted_at"
  end

  create_table "system_inquiries", :force => true do |t|
    t.integer  "unid"
    t.text     "state",      :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id"
    t.integer  "group_id"
    t.text     "charge"
    t.text     "tel"
    t.text     "fax"
    t.text     "email"
  end

  create_table "system_languages", :force => true do |t|
    t.text     "state"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "sort_no"
    t.text     "name"
    t.text     "title"
  end

  create_table "system_ldap_temporaries", :force => true do |t|
    t.integer  "parent_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "version"
    t.string   "data_type"
    t.string   "code"
    t.string   "sort_no"
    t.text     "name"
    t.text     "name_en"
    t.text     "kana"
    t.text     "email"
    t.text     "match"
    t.string   "official_position"
    t.string   "assigned_job"
  end

  add_index "system_ldap_temporaries", ["version", "parent_id", "data_type", "sort_no"], :name => "version", :length => {"version"=>20, "parent_id"=>nil, "data_type"=>20, "sort_no"=>nil}

  create_table "system_login_logs", :force => true do |t|
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "system_login_logs", ["user_id"], :name => "user_id"

  create_table "system_maps", :force => true do |t|
    t.integer  "unid"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "name"
    t.text     "title"
    t.text     "map_lat"
    t.text     "map_lng"
    t.text     "map_zoom"
    t.text     "point1_name"
    t.text     "point1_lat"
    t.text     "point1_lng"
    t.text     "point2_name"
    t.text     "point2_lat"
    t.text     "point2_lng"
    t.text     "point3_name"
    t.text     "point3_lat"
    t.text     "point3_lng"
    t.text     "point4_name"
    t.text     "point4_lat"
    t.text     "point4_lng"
    t.text     "point5_name"
    t.text     "point5_lat"
    t.text     "point5_lng"
  end

  create_table "system_priv_names", :force => true do |t|
    t.integer  "unid"
    t.text     "state"
    t.integer  "content_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "display_name"
    t.text     "priv_name"
    t.integer  "sort_no"
  end

  create_table "system_public_logs", :force => true do |t|
    t.datetime "created_at"
    t.integer  "user_id"
    t.integer  "item_unid"
    t.text     "controller"
    t.text     "action"
  end

  create_table "system_publishers", :force => true do |t|
    t.integer  "unid"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "published_at"
    t.text     "name"
    t.text     "published_path"
    t.text     "content_type"
    t.integer  "content_length"
  end

  create_table "system_recognitions", :force => true do |t|
    t.integer  "unid"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "after_process"
  end

  create_table "system_recognizers", :force => true do |t|
    t.integer  "unid"
    t.datetime "updated_at"
    t.datetime "created_at"
    t.text     "name",          :null => false
    t.integer  "user_id"
    t.datetime "recognized_at"
  end

  create_table "system_role_developers", :force => true do |t|
    t.integer  "idx"
    t.integer  "class_id"
    t.string   "uid"
    t.integer  "priv"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "role_name_id"
    t.text     "table_name"
    t.text     "priv_name"
    t.integer  "priv_user_id"
  end

  create_table "system_role_name_privs", :force => true do |t|
    t.integer  "role_id"
    t.integer  "priv_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "system_role_names", :force => true do |t|
    t.integer  "unid"
    t.text     "state"
    t.integer  "content_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "display_name"
    t.text     "table_name"
    t.integer  "sort_no"
  end

  create_table "system_roles", :force => true do |t|
    t.string   "table_name"
    t.string   "priv_name"
    t.integer  "idx"
    t.integer  "class_id"
    t.string   "uid"
    t.integer  "priv"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "role_name_id"
    t.integer  "priv_user_id"
    t.integer  "group_id"
  end

  create_table "system_sequences", :force => true do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "name"
    t.integer  "version"
    t.integer  "value"
  end

  create_table "system_tags", :force => true do |t|
    t.integer  "unid"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "name"
    t.text     "word"
  end

  create_table "system_tasks", :force => true do |t|
    t.integer  "unid"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "process_at"
    t.text     "name"
  end

  create_table "system_unids", :force => true do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "module"
    t.text     "item_type"
    t.integer  "item_id"
  end

  create_table "system_user_temporaries", :force => true do |t|
    t.string   "air_login_id"
    t.text     "state"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "code",                      :null => false
    t.integer  "ldap",                      :null => false
    t.integer  "ldap_version"
    t.text     "auth_no"
    t.string   "sort_no"
    t.text     "name"
    t.text     "name_en"
    t.text     "kana"
    t.text     "password"
    t.integer  "mobile_access"
    t.string   "mobile_password"
    t.text     "email"
    t.string   "official_position"
    t.string   "assigned_job"
    t.text     "remember_token"
    t.datetime "remember_token_expires_at"
    t.text     "air_token"
  end

  add_index "system_user_temporaries", ["code"], :name => "unique_user_code", :unique => true

  create_table "system_users", :force => true do |t|
    t.string   "air_login_id"
    t.text     "state"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "code",                      :null => false
    t.integer  "ldap",                      :null => false
    t.integer  "ldap_version"
    t.text     "auth_no"
    t.string   "sort_no"
    t.text     "name"
    t.text     "name_en"
    t.text     "kana"
    t.text     "password"
    t.integer  "mobile_access"
    t.string   "mobile_password"
    t.text     "email"
    t.string   "official_position"
    t.string   "assigned_job"
    t.text     "remember_token"
    t.datetime "remember_token_expires_at"
    t.text     "air_token"
  end

  add_index "system_users", ["code"], :name => "unique_user_code", :unique => true

  create_table "system_users_custom_groups", :primary_key => "rid", :force => true do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "custom_group_id"
    t.integer  "user_id"
    t.text     "title"
    t.text     "title_en"
    t.integer  "sort_no"
    t.text     "icon"
  end

  add_index "system_users_custom_groups", ["custom_group_id"], :name => "custom_group_id"

  create_table "system_users_group_histories", :primary_key => "rid", :force => true do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id"
    t.integer  "group_id"
    t.integer  "job_order"
    t.datetime "start_at"
    t.datetime "end_at"
    t.string   "user_code"
    t.string   "group_code"
  end

  create_table "system_users_group_history_temporaries", :primary_key => "rid", :force => true do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id"
    t.integer  "group_id"
    t.integer  "job_order"
    t.datetime "start_at"
    t.datetime "end_at"
    t.string   "user_code"
    t.string   "group_code"
  end

  create_table "system_users_group_temporaries", :primary_key => "rid", :force => true do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id"
    t.integer  "group_id"
    t.integer  "job_order"
    t.datetime "start_at"
    t.datetime "end_at"
    t.string   "user_code"
    t.string   "group_code"
  end

  create_table "system_users_groups", :primary_key => "rid", :force => true do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id"
    t.integer  "group_id"
    t.integer  "job_order"
    t.datetime "start_at"
    t.datetime "end_at"
    t.string   "user_code"
    t.string   "group_code"
  end

  create_table "system_users_groups_csvdata", :force => true do |t|
    t.string   "state",             :null => false
    t.string   "data_type",         :null => false
    t.integer  "level_no"
    t.integer  "parent_id",         :null => false
    t.string   "parent_code",       :null => false
    t.string   "code",              :null => false
    t.integer  "sort_no"
    t.integer  "ldap",              :null => false
    t.integer  "job_order"
    t.text     "name",              :null => false
    t.text     "name_en"
    t.text     "kana"
    t.string   "password"
    t.integer  "mobile_access"
    t.string   "mobile_password"
    t.string   "email"
    t.string   "official_position"
    t.string   "assigned_job"
    t.datetime "start_at",          :null => false
    t.datetime "end_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
