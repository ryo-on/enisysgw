class CreateView < ActiveRecord::Migration
  def up
    execute <<-SQL
    CREATE OR REPLACE VIEW doclibrary_view_acl_docs AS
      SELECT
        doclibrary_docs.id AS id,
        doclibrary_folders.sort_no AS sort_no,
        doclibrary_folder_acls.acl_flag AS acl_flag,
        doclibrary_folder_acls.acl_section_id AS acl_section_id,
        doclibrary_folder_acls.acl_section_code AS acl_section_code,
        doclibrary_folder_acls.acl_section_name AS acl_section_name,
        doclibrary_folder_acls.acl_user_id AS acl_user_id,
        doclibrary_folder_acls.acl_user_code AS acl_user_code,
        doclibrary_folder_acls.acl_user_name AS acl_user_name,
        doclibrary_folders.name AS folder_name
      FROM ((doclibrary_docs JOIN doclibrary_folder_acls ON ((
        (doclibrary_docs.title_id = doclibrary_folder_acls.title_id) AND
        (doclibrary_docs.category1_id = doclibrary_folder_acls.folder_id))
        )) JOIN doclibrary_folders ON ((doclibrary_docs.category1_id = doclibrary_folders.id)
      ));
    SQL

    execute <<-SQL
    CREATE OR REPLACE VIEW doclibrary_view_acl_files AS
      SELECT
        doclibrary_docs.state AS docs_state,
        doclibrary_files.id AS id,
        doclibrary_files.unid AS unid,
        doclibrary_files.content_id AS content_id,
        doclibrary_files.state AS state,
        doclibrary_files.created_at AS created_at,
        doclibrary_files.updated_at AS updated_at,
        doclibrary_files.recognized_at AS recognized_at,
        doclibrary_files.published_at AS published_at,
        doclibrary_files.latest_updated_at AS latest_updated_at,
        doclibrary_files.parent_id AS parent_id,
        doclibrary_files.title_id AS title_id,
        doclibrary_files.content_type AS content_type,
        doclibrary_files.filename AS filename,
        doclibrary_files.memo AS memo,
        doclibrary_files.size AS size,
        doclibrary_files.width AS width,
        doclibrary_files.height AS height,
        doclibrary_files.db_file_id AS db_file_id,
        doclibrary_docs.category1_id AS category1_id,
        doclibrary_docs.section_code AS section_code,
        doclibrary_folder_acls.acl_flag AS acl_flag,
        doclibrary_folder_acls.acl_section_id AS acl_section_id,
        doclibrary_folder_acls.acl_section_code AS acl_section_code,
        doclibrary_folder_acls.acl_section_name AS acl_section_name,
        doclibrary_folder_acls.acl_user_id AS acl_user_id,
        doclibrary_folder_acls.acl_user_code AS acl_user_code,
        doclibrary_folder_acls.acl_user_name AS acl_user_name
      FROM ((doclibrary_files JOIN doclibrary_docs ON ((
          (doclibrary_files.parent_id = doclibrary_docs.id) AND
          (doclibrary_files.title_id = doclibrary_docs.title_id)
        ))) JOIN doclibrary_folder_acls ON ((
          (doclibrary_docs.category1_id = doclibrary_folder_acls.folder_id) AND
          (doclibrary_docs.title_id = doclibrary_folder_acls.title_id)
      )));
    SQL

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

    execute <<-SQL
    CREATE OR REPLACE VIEW doclibrary_view_acl_doc_counts AS
      SELECT
        doclibrary_docs.state AS state,
        doclibrary_docs.title_id AS title_id,
        doclibrary_folder_acls.acl_flag AS acl_flag,
        doclibrary_folder_acls.acl_section_code AS acl_section_code,
        doclibrary_folder_acls.acl_user_code AS acl_user_code,
        doclibrary_docs.section_code AS section_code,
        COUNT(doclibrary_docs.id) AS cnt
      FROM (doclibrary_docs JOIN doclibrary_folder_acls ON ((
        (doclibrary_docs.category1_id = doclibrary_folder_acls.folder_id) AND
        (doclibrary_docs.title_id = doclibrary_folder_acls.title_id)
      )))
      GROUP BY
        doclibrary_docs.state,
        doclibrary_docs.title_id,
        doclibrary_folder_acls.acl_flag,
        doclibrary_folder_acls.acl_section_code,
        doclibrary_folder_acls.acl_user_code,
        doclibrary_docs.section_code;
    SQL
  end

  def down
    execute <<-SQL
      DROP VIEW doclibrary_view_acl_docs;
    SQL

    execute <<-SQL
      DROP VIEW doclibrary_view_acl_files;
    SQL

    execute <<-SQL
      DROP VIEW doclibrary_view_acl_folders;
    SQL

    execute <<-SQL
      DROP VIEW doclibrary_view_acl_doc_counts;
    SQL
  end
end
