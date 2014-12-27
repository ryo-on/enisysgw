# encoding: utf-8
class CreateSystemUsersProfileSettings < ActiveRecord::Migration
  def change
    create_table :system_users_profile_settings do |t|
      t.string :key_name
      t.string :name
      t.integer :used

      t.timestamps
    end
    execute "insert into system_users_profile_settings values
      (1,'name','名前',1,now(),now()),
      (2,'name_en','名前（英）',0,now(),now()),
      (3,'email','メールアドレス',1,now(),now()),
      (4,'official_position','役職',1,now(),now()),
      (5,'assigned_job','担当',0,now(),now()),
      (6,'add_column1','',1,now(),now()),
      (7,'add_column2','',1,now(),now()),
      (8,'add_column3','',1,now(),now()),
      (9,'add_column4','',1,now(),now()),
      (10,'add_column5','',1,now(),now())"
  end
end
