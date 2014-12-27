class ReplaceViewDoclibraryViewAclFolders < ActiveRecord::Migration
  def up
    execute <<-SQL
    CREATE OR REPLACE VIEW doclibrary_view_acl_folders AS
      SELECT 
        doclibrary_folders.id AS id,
        doclibrary_folders.unid AS unid,
        doclibrary_folders.parent_id AS parent_id,
        doclibrary_folders.state AS state,
        doclibrary_folders.created_at AS created_at,
        doclibrary_folders.updated_at AS updated_at,
        doclibrary_folders.title_id AS title_id,
        doclibrary_folders.sort_no AS sort_no,
        doclibrary_folders.level_no AS level_no,
        doclibrary_folders.children_size AS children_size,
        doclibrary_folders.total_children_size AS total_children_size,
        doclibrary_folders.name AS name,
        doclibrary_folders.memo AS memo,
        doclibrary_folders.admins AS admins,
        doclibrary_folders.admins_json AS admins_json,
        doclibrary_folders.admin_groups AS admin_groups,
        doclibrary_folders.admin_groups_json AS admin_groups_json,
        doclibrary_folders.readers AS readers,
        doclibrary_folders.readers_json AS readers_json,
        doclibrary_folders.reader_groups AS reader_groups,
        doclibrary_folders.reader_groups_json AS reader_groups_json,
        doclibrary_folders.docs_last_updated_at AS docs_last_updated_at,
        doclibrary_folder_acls.acl_flag AS acl_flag,
        doclibrary_folder_acls.acl_section_id AS acl_section_id,
        doclibrary_folder_acls.acl_section_code AS acl_section_code,
        doclibrary_folder_acls.acl_section_name AS acl_section_name,
        doclibrary_folder_acls.acl_user_id AS acl_user_id,
        doclibrary_folder_acls.acl_user_code AS acl_user_code,
        doclibrary_folder_acls.acl_user_name AS acl_user_name
      FROM (doclibrary_folder_acls JOIN doclibrary_folders ON ((
        (doclibrary_folder_acls.folder_id = doclibrary_folders.id) AND
        (doclibrary_folder_acls.title_id = doclibrary_folders.title_id)
      )));
    SQL
  end

  def down
    execute <<-SQL
    CREATE OR REPLACE VIEW doclibrary_view_acl_folders AS
      SELECT 
        doclibrary_folders.id AS id,
        doclibrary_folders.unid AS unid,
        doclibrary_folders.parent_id AS parent_id,
        doclibrary_folders.state AS state,
        doclibrary_folders.created_at AS created_at,
        doclibrary_folders.updated_at AS updated_at,
        doclibrary_folders.title_id AS title_id,
        doclibrary_folders.sort_no AS sort_no,
        doclibrary_folders.level_no AS level_no,
        doclibrary_folders.children_size AS children_size,
        doclibrary_folders.total_children_size AS total_children_size,
        doclibrary_folders.name AS name,
        doclibrary_folders.memo AS memo,
        doclibrary_folders.readers AS readers,
        doclibrary_folders.readers_json AS readers_json,
        doclibrary_folders.reader_groups AS reader_groups,
        doclibrary_folders.reader_groups_json AS reader_groups_json,
        doclibrary_folders.docs_last_updated_at AS docs_last_updated_at,
        doclibrary_folder_acls.acl_flag AS acl_flag,
        doclibrary_folder_acls.acl_section_id AS acl_section_id,
        doclibrary_folder_acls.acl_section_code AS acl_section_code,
        doclibrary_folder_acls.acl_section_name AS acl_section_name,
        doclibrary_folder_acls.acl_user_id AS acl_user_id,
        doclibrary_folder_acls.acl_user_code AS acl_user_code,
        doclibrary_folder_acls.acl_user_name AS acl_user_name
      FROM (doclibrary_folder_acls JOIN doclibrary_folders ON ((
        (doclibrary_folder_acls.folder_id = doclibrary_folders.id) AND
        (doclibrary_folder_acls.title_id = doclibrary_folders.title_id)
      )));
    SQL
  end
end
