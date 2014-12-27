# -*- encoding: utf-8 -*-

class Doclibrary::Admin::DocsController < Gw::Controller::Admin::Base

  include Gwboard::Controller::Scaffold
  include Gwboard::Controller::Common
  include Doclibrary::Model::DbnameAlias
  include Rumi::Doclibrary::Authorize
  include Doclibrary::Admin::DocsHelper
  include Doclibrary::Admin::IndicesHelper

  layout "admin/template/doclibrary"

  def initialize_scaffold
    @title = Doclibrary::Control.find_by_id(params[:title_id])
    return http_error(404) unless @title

    # 内容一覧（分類順）画面かどうかのフラグ
    @is_category_index_form =
        (action_name == 'index') && (params[:state] == "CATEGORY" || params[:state].blank?)

    # 検索結果一覧画面かどうかのフラグ
    @is_doc_searching = doc_searching?

    Page.title = @title.title
    return redirect_to("#{doclibrary_docs_path}?title_id=#{params[:title_id]}&limit=#{params[:limit]}&state=#{params[:state]}") if params[:reset]

    admin_flags(@title.id)

    if params[:state].blank?
      params[:state] = 'CATEGORY' unless params[:cat].blank?
      params[:state] = 'GROUP' unless params[:gcd].blank?
      if params[:cat].blank?
        params[:state] = @title.default_folder.to_s if params[:state].blank?
      end if params[:gcd].blank?
    end
    begin
      _search_condition
    rescue
      return http_error(404)
    end
    initialize_value_set
  end

  def _search_condition
    group_hash
    category_hash
    Doclibrary::Doc.remove_connection

    case params[:state]
    when 'CATEGORY'
      params[:cat] = 1 if params[:cat].blank?
      item = doclib_db_alias(Doclibrary::Folder)
      @parent = item.find_by_id(params[:cat])
      return http_error(404) unless @parent
    else
      if params[:cat].present?
        item = doclib_db_alias(Doclibrary::Folder)
        @parent = item.find_by_id(params[:cat])
        return http_error(404) unless @parent
      end
    end
    Doclibrary::Folder.remove_connection
    Doclibrary::GroupFolder.remove_connection
  end

  def group_hash
    # 閲覧可能フォルダのID取得
    readable_folders = get_readable_folder
    readable_folder_ids = readable_folders.map{|f| f.id}

    item = doclib_db_alias(Doclibrary::Doc)
    item = item.new
    item.and :title_id , @title.id
    item.and :state, 'public' unless params[:state].to_s == 'DRAFT'
    item.and :state, 'draft' if params[:state].to_s == 'DRAFT'
    item.and :category1_id, readable_folder_ids

    items = item.find(:all, :select=>'section_code',:group => 'section_code')
    sql = Condition.new
    if items.blank?
      sql.and :id, 0
    else
      for citem in items
        sql.or :code, citem.section_code
      end
    end
    @select_groups = Gwboard::Group.new.find(:all,:conditions=>sql.where, :select=>'code, name' , :order=>'sort_no, code')
    @groups = Gwboard::Group.level3_all_hash
  end

  # === 閲覧可能フォルダ取得メソッド
  #  本メソッドは、指定ユーザーの閲覧可能なフォルダを取得するメソッドである。
  # ==== 引数
  #  * user_id: ユーザーID
  # ==== 戻り値
  #  閲覧可能フォルダ(Doclibrary::Folder)
  def get_readable_folder(user_id = Site.user.id)
    is_admin = @is_admin.blank? ? FALSE : TRUE

    # 指定ユーザーの所属グループID取得（親グループを含む）
    target_user = System::User.find(user_id)
    user_group_parent_ids = target_user.user_group_parent_ids.join(",")

    str_where  = " (state = 'public' AND doclibrary_folders.title_id = #{@title.id}) AND ((acl_flag = 0)"
    if is_admin
      str_where  += " OR (acl_flag = 9))"
    elsif user_group_parent_ids.size != 0
        str_where  += " OR (acl_flag = 1 AND acl_section_id IN (#{user_group_parent_ids}))"
        str_where  += " OR (acl_flag = 2 AND acl_user_id = #{target_user.id}))"
    else
        str_where  += ")"
    end

    str_sql = 'SELECT doclibrary_folders.id FROM doclibrary_folder_acls, doclibrary_folders'
    str_sql += ' WHERE doclibrary_folder_acls.folder_id = doclibrary_folders.id'
    str_sql += ' AND ( ' + str_where + ' )'
    str_sql += ' GROUP BY doclibrary_folders.id'

    cnn = doclib_db_alias(Doclibrary::ViewAclFolder)
    items = cnn.find_by_sql(str_sql)
    folder_ids = items.map{|f| f.id}.join(",")
    cnn.remove_connection

    folders = []
    unless folder_ids.blank?
      cnn = doclib_db_alias(Doclibrary::Folder)
      folders = cnn.where("id IN (#{folder_ids})")
                   .order("sort_no, id")
      cnn.remove_connection
    end
    return folders
  end

  def category_hash
    item = doclib_db_alias(Doclibrary::Folder)
    item = item.new
    item.and :state, 'public'
    item.and :title_id , params[:title_id]
    @categories = item.find(:all, :select => 'id, name').index_by(&:id)

    item = doclib_db_alias(Doclibrary::Folder)
    parent = item.find(:all, :conditions=>["parent_id IS NULL"], :order=>"level_no, sort_no, id")
    @select_categories = []
    make_group_trees(parent) unless params[:state] == "CATEGORY"
  end

  def make_group_trees(items)
    items.each do |item|
      str = "+"
      str += "-" * (item.level_no - 1)
      cnn = doclib_db_alias(Doclibrary::Folder)
      folder = cnn.find(item.id)
      if folder.present? && folder.readable_user? &&
          (item.level_no >= 1 && item.state == 'public')
        @select_categories << [item.id , str + item.name]
      end
      Doclibrary::Folder.remove_connection
      make_group_trees(item.children) if item.children.count > 0
    end if items.count > 0
  end

  def index
    get_role_index
    return authentication_error(403) unless @is_readable
    return authentication_error(403) if @is_category_index_form && !@parent.readable_user?

    if @title.form_name == 'form002'
      index_form002
    else
      index_form001
    end

    Doclibrary::Doc.remove_connection
    Doclibrary::File.remove_connection
    Doclibrary::Folder.remove_connection
    Doclibrary::FolderAcl.remove_connection
    Doclibrary::GroupFolder.remove_connection
  end

  def index_form001
    case params[:state]
    when 'DRAFT'
      category_folder_items('draft') unless doc_searching?
      normal_draft_index
    when 'RECOGNIZE'
      recognize_index
    when 'PUBLISH'
      recognized_index
    else
      category_folder_items unless doc_searching?
      normal_category_index_form001
    end

    # キーワードが入力された場合のみ、添付ファイル一覧を表示
    search_files_index unless params[:kwd].blank?

    begin
      # 一括ダウンロードボタンがクリックされた場合、ファイルのダウンロード実行
      export_zip_file unless params[:download].blank?
    rescue => ex
      flash.now[:error] = ex.message
    end
  end

  def index_form002
    unless params[:kwd].blank?
      search_index_docs
    else
      if params[:state].to_s== 'DRAFT'
       normal_draft_index_form002
      else
       normal_category_index
      end
    end
  end

  def new
    get_role_new

    # ファイル作成できるか？（いずれかのフォルダに管理権限があるか？）
    return authentication_error(403) unless @has_some_folder_admin

    # カレントフォルダに管理権限があるか?
    category1_id = params[:cat]
    unless params[:cat].blank?
      folder_cnn = doclib_db_alias(Doclibrary::Folder)
      folder = folder_cnn.find(params[:cat])
      unless folder.present? && folder.admin_user?
        # カレントフォルダに管理権限がない場合、フォルダの初期値クリア
        category1_id = ""
      end
      Doclibrary::Folder.remove_connection
    end

    item = doclib_db_alias(Doclibrary::Doc)
    str_section_code = Site.user_group.code
    str_section_code = params[:gcd].to_s unless params[:gcd].to_s == '1' unless params[:gcd].blank?
    @item = item.create({
      :state => 'preparation',
      :title_id => @title.id ,
      :latest_updated_at => Time.now,
      :importance=> 1,
      :one_line_note => 0,
      :section_code => str_section_code ,
      :category4_id => 0,
      :category1_id => category1_id
    })

    @item.state = 'draft'

    set_folder_level_code
    form002_categories if @title.form_name == 'form002'
    users_collection unless @title.recognize == 0
  end

  def is_i_have_readable(folder_id)
    return true if @is_recognize_readable
    return false if folder_id.blank?
    p_grp_code = ''
    p_grp_code = Site.user_group.parent.code unless Site.user_group.parent.blank?
    grp_code = ''
    grp_code = Site.user_group.code unless Site.user_group.blank?

    sql = Condition.new
    sql.or {|d|
      d.and :title_id , @title.id
      d.and :folder_id, folder_id
      d.and :acl_flag , 0
    }
    if @is_admin

      sql.or {|d|
        d.and :title_id , @title.id
        d.and :folder_id, folder_id
        d.and :acl_flag , 9
      }
    else

      sql.or {|d|
        d.and :title_id , @title.id
        d.and :folder_id, folder_id
        d.and :acl_flag , 1
        d.and :acl_section_code , p_grp_code
      }

      sql.or {|d|
        d.and :title_id , @title.id
        d.and :folder_id, folder_id
        d.and :acl_flag , 1
        d.and :acl_section_code , grp_code
      }

      sql.or {|d|
        d.and :title_id , @title.id
        d.and :folder_id, folder_id
        d.and :acl_flag , 2
        d.and :acl_user_code , Site.user.code
      }
    end
    item = doclib_db_alias(Doclibrary::FolderAcl)
    item = item.new
    items = item.find(:all, :conditions => sql.where)
    Doclibrary::FolderAcl.remove_connection
    return false if items.blank?
    return false if items.count == 0
    return true unless items.count == 0
  end

  def show
    get_role_index
    return authentication_error(403) unless @is_readable

    admin_flags(params[:title_id])

    @is_recognize = check_recognize
    @is_recognize_readable = check_recognize_readable

    item = doclib_db_alias(Doclibrary::Doc)
    item = item.new
    item.and :id, params[:id]
    @item = item.find(:first)
    Doclibrary::Doc.remove_connection
    return http_error(404) unless @item
    get_role_show(@item)
    Page.title = @item.title
    @parent = @item.parent
    return authentication_error(403) unless @parent.readable_user?

    unless @is_admin
      if @item.state=='draft'
        user_groups = Site.user.enable_user_groups
        user_groups_code = user_groups.map{|group| group.group_code} unless user_groups.blank?
        unless user_groups_code.present? || user_groups_code.include?(@item.section_code)
          return http_error(404)
        end
      end
    end

    @is_recognize = false unless @item.state == 'recognize'

    get_role_show(@item)
    @is_readable = true if @is_recognize_readable
    return authentication_error(403) unless @is_readable

    item = doclib_db_alias(Doclibrary::File)
    item = item.new
    item.and :title_id, @title.id
    item.and :parent_id, @item.id unless @title.form_name == 'form002'
    item.and :parent_id, @item.category2_id if @title.form_name == 'form002'
    item.order  'id'
    @files = item.find(:all)
    Doclibrary::File.remove_connection

    get_recogusers
    @is_publish = true if @is_admin if @item.state == 'recognized'
    user_groups = Site.user.enable_user_groups
    user_groups_code = user_groups.map{|group| group.group_code} unless user_groups.blank?
    if user_groups_code.present? && user_groups_code.include?(@item.section_code)
      @is_publish = true if @item.state == 'recognized'
    end
  end

  def edit
    get_role_new

    item = doclib_db_alias(Doclibrary::Doc)
    item = item.new
    item.and :id, params[:id]
    @item = item.find(:first)
    Doclibrary::Doc.remove_connection
    return http_error(404) unless @item

    # ファイルを編集できるか？（ファイルの親フォルダに管理権限があるか？）
    return authentication_error(403) unless @item.parent.admin_user?

    set_folder_level_code
    form002_categories if @title.form_name == 'form002'
    unless @title.recognize == 0
      get_recogusers
      set_recogusers
      users_collection('edit')
    end

    # 編集開始日時の取得
    @edit_start = Time.now
    params[:edit_start] = @edit_start if params[:edit_start].blank?
  end

  def update
    get_role_new

    item = doclib_db_alias(Doclibrary::Doc)
    @item = item.find(params[:id])
    return http_error(404) unless @item

    set_folder_level_code
    form002_categories if @title.form_name == 'form002'
    unless @title.recognize.to_s == '0'
      users_collection
    end

    item = doclib_db_alias(Doclibrary::File)
    item = item.new
    item.and :title_id, @title.id
    item.and :parent_id, params[:id]
    item.order 'id'
    @files = item.find(:all)
    Doclibrary::File.remove_connection
    attach = 0
    attach = @files.length unless @files.blank?

    item = doclib_db_alias(Doclibrary::Doc)
    @item = item.find(params[:id])
    @item.attributes = params[:item]
    @item.latest_updated_at = Time.now
    @item.attachmentfile = attach
    @item.category_use = 1
    @item.form_name = @title.form_name

    group = Gwboard::Group.new
    group.and :state , 'enabled'
    group.and :code ,@item.section_code
    group = group.find(:first)
    @item.section_name = group.code + group.name if group
    @item._note_section = group.name if group

    update_creater_editor

    if @title.form_name == 'form002'
      set_form002_params
      @item.note = return_form002_attached_url
    end
    section_folder_state_update

    if @title.notification == 1
      note = doclib_db_alias(Doclibrary::FolderAcl)
      note = note.new
      note.and :title_id,  @title.id
      note.and :folder_id, @item.category1_id
      note.and :acl_flag, '<', 9
      notes = note.find(:all)
      @item._acl_records = notes
      @item._notification = @title.notification
      @item._bbs_title_name = @title.title
    end

    if @title.recognize == 0
      _update_plus_location @item, doclibrary_docs_path({:title_id=>@title.id}) + doclib_uri_params
    else
      _update_after_save_recognizers(@item, doclib_db_alias(Doclibrary::Recognizer), doclibrary_docs_path({:title_id=>@title.id}) + doclib_uri_params)
    end
  end

  def destroy
    item = doclib_db_alias(Doclibrary::Doc)
    @item = item.find(params[:id])

    get_role_edit(@item)

    # ファイル削除できるか？（ファイルの親フォルダに管理権限があるか？）
    return authentication_error(403) unless @item.parent.admin_user?

    destroy_atacched_files
    destroy_files

    @item._notification = @title.notification
    _destroy_plus_location @item,doclibrary_docs_path({:title_id=>@title.id}) + doclib_uri_params
  end

  def edit_file_memo
    get_role_index
    return authentication_error(403) unless @is_readable

    item = doclib_db_alias(Doclibrary::Doc)
    item = item.new
    item.and :id, params[:parent_id]
    Doclibrary::Doc
    @item = item.find(:first)
    return http_error(404) unless @item
    get_role_show(@item)

    item = doclib_db_alias(Doclibrary::File)
    item = item.new
    item.and :title_id, @title.id
    item.and :parent_id, @item.id unless @title.form_name == 'form002'
    item.and :parent_id, @item.category2_id if @title.form_name == 'form002'
    item.order  'id'
    @files = item.find(:all)

    item = doclib_db_alias(Doclibrary::File)
    item = item.new
    @file = item.find(params[:id])
  end

  def docs_state_from_params
    case params[:state]
    when 'DRAFT'
      'draft'
    when 'RECOGNIZE'
      'recognize'
    when 'PUBLISH'
      'recognized'
    else
      'public'
    end
  end

  def search_files_index
    item = doclib_db_alias(Doclibrary::ViewAclFile)
    item = item.new
    item.id = nil
    item.and "doclibrary_view_acl_files.title_id", @title.id
    item.and "doclibrary_view_acl_files.docs_state", docs_state_from_params
    item.and item.get_keywords_condition(params[:kwd], :filename) unless params[:kwd].blank?

    # ログインユーザーの所属グループコードを取得（親グループを含む）
    user_group_parent_codes = []
    Site.user.enable_user_groups.each do |user_group|
      user_group_parent_codes += user_group.group.parent_tree.map(&:code)
    end
    user_group_parent_codes.uniq!

    case params[:state]
    when 'DATE'
      item.and "doclibrary_view_acl_files.section_code", params[:gcd] unless params[:gcd].blank?
      item.and "doclibrary_view_acl_files.category1_id", params[:cat] unless params[:cat].blank?
    when 'GROUP'
      item.and "doclibrary_view_acl_files.section_code", section_codes_narrow_down unless params[:gcd].blank?
      item.and "doclibrary_view_acl_files.category1_id", params[:cat] unless params[:cat].blank?
    when 'CATEGORY'
      item.and "doclibrary_view_acl_files.section_code", params[:gcd] unless params[:gcd].blank?
      item.and "doclibrary_view_acl_files.category1_id", category_ids_narrow_down unless params[:kwd].blank?
      item.and "doclibrary_view_acl_files.category1_id", params[:cat] unless params[:cat].blank? if params[:kwd].blank?
    when 'DRAFT', 'PUBLISH'
      item.and 'doclibrary_view_acl_files.section_code', user_group_parent_codes unless @is_admin
    when 'RECOGNIZE'
      unless @is_admin
        item.and {|d|
          user_groups = Site.user.enable_user_groups
          user_groups_code = user_groups.map{|group| group.group_code} if user_groups.blank?
          d.or "doclibrary_view_acl_files.section_code", user_groups_code unless user_groups_code.blank?
          d.or "doclibrary_recognizers.code", Site.user.code
          d.or "doclibrary_docs.creater_id", Site.user.code
        }
      end
    end

    item.and {|d|
      d.or {|d2|
        d2.and "doclibrary_view_acl_files.acl_flag", 0
      }
      if @is_admin
        d.or {|d2|
          d2.and "doclibrary_view_acl_files.acl_flag", 9
        }
      else
        d.or {|d2|
          d2.and "doclibrary_view_acl_files.acl_flag", 1
          d2.and "doclibrary_view_acl_files.acl_section_code", user_group_parent_codes
        }
        d.or {|d2|
          d2.and "doclibrary_view_acl_files.acl_flag", 2
          d2.and "doclibrary_view_acl_files.acl_user_code", Site.user.code
        }
      end
    }

    case params[:state]
    when 'DATE'
      item.order "doclibrary_view_acl_files.updated_at DESC, doclibrary_view_acl_files.created_at DESC, doclibrary_view_acl_files.filename"
    when 'GROUP'
      item.order "doclibrary_view_acl_files.section_code, doclibrary_view_acl_files.category1_id, doclibrary_view_acl_files.updated_at DESC, doclibrary_view_acl_files.created_at DESC, doclibrary_view_acl_files.filename"
    else
      item.order "doclibrary_view_acl_files.filename, doclibrary_view_acl_files.updated_at DESC, doclibrary_view_acl_files.created_at DESC"
    end

    item.join "LEFT JOIN doclibrary_recognizers ON doclibrary_view_acl_files.parent_id = doclibrary_recognizers.parent_id AND doclibrary_view_acl_files.title_id = doclibrary_recognizers.title_id"
    item.join "LEFT JOIN doclibrary_docs ON doclibrary_view_acl_files.parent_id = doclibrary_docs.id AND doclibrary_view_acl_files.title_id = doclibrary_docs.title_id"
    item.page params[:page], params[:limit]
    @files = item.find(:all).group('doclibrary_view_acl_files.id')
  end

  def section_codes_narrow_down
    section_codes = []
    unless params[:gcd].blank?
      item = doclib_db_alias(Doclibrary::GroupFolder)
      item = item.new
      item.and :title_id, @title.id
      item.and :state, 'public'
      item.and :code, params[:gcd].to_s
      items = item.find(:all)
      section_codes += section_narrow(items) if items
    end
    section_codes
  end
  def section_narrow(items)
    section_codes = []
    items.each do |item|
      section_codes << item.code
      section_narrow(item.children) if item.children.size > 0
    end
    section_codes
  end

  def normal_category_index_form001
    user_groups = Site.user.enable_user_groups
    user_groups_code = user_groups.map{|group| group.group_code} unless user_groups.blank?

    item = doclib_db_alias(Doclibrary::Doc)
    item = item.new
    item.and 'doclibrary_docs.state', 'public'
    item.and 'doclibrary_docs.title_id', @title.id
    item.and item.get_keywords_condition(params[:kwd], :title, :body) unless params[:kwd].blank?
    item.and item.get_creator_condition(params[:creator], :creater, :createrdivision_id) unless params[:creator].blank?
    item.and(
        item.get_date_condition(params[:term_start], 
        'doclibrary_docs.created_at', {:is_term_start => true})) if params[:term_start].present?
    item.and(
        item.get_date_condition(params[:term_finish], 
        'doclibrary_docs.created_at', {:is_term_start => false})) if params[:term_finish].present?

    case params[:state]
    when 'DATE'
      item.and 'doclibrary_docs.section_code', params[:gcd] unless params[:gcd].blank?
      item.and 'doclibrary_docs.category1_id', params[:cat] unless params[:cat].blank?
    when 'GROUP'
      item.and 'doclibrary_docs.section_code', section_codes_narrow_down unless params[:gcd].blank?
      item.and 'doclibrary_docs.category1_id', params[:cat] unless params[:cat].blank?
    when 'CATEGORY'
      item.and 'doclibrary_docs.section_code', params[:gcd] unless params[:gcd].blank?
      item.and 'doclibrary_docs.category1_id', category_ids_narrow_down if doc_searching?
      item.and 'doclibrary_docs.category1_id', params[:cat] unless params[:cat].blank? unless doc_searching?
    end

    item.and {|d|
      d.or {|d2|
        d2.and 'doclibrary_view_acl_docs.acl_flag', 0
      }
      if @is_admin
        d.or {|d2|
          d2.and 'doclibrary_view_acl_docs.acl_flag', 9
        }
      else
        d.or {|d2|
          d2.and 'doclibrary_view_acl_docs.acl_flag', 1
          d2.and 'doclibrary_view_acl_docs.acl_section_code', user_groups_code unless user_groups_code.blank?
        }
        d.or {|d2|
          d2.and 'doclibrary_view_acl_docs.acl_flag', 2
          d2.and 'doclibrary_view_acl_docs.acl_user_code', Site.user.code
        }
      end
    }

    case params[:state]
    when 'DATE'
      item.order "doclibrary_docs.updated_at DESC, doclibrary_docs.created_at DESC, doclibrary_view_acl_docs.sort_no, doclibrary_docs.category1_id, doclibrary_docs.title"
    when 'GROUP'
      item.order "doclibrary_docs.section_code, doclibrary_view_acl_docs.sort_no, doclibrary_docs.category1_id, doclibrary_docs.updated_at DESC, doclibrary_docs.created_at DESC"
    else
      item.order "doclibrary_view_acl_docs.sort_no, section_code, doclibrary_docs.title, doclibrary_docs.updated_at DESC, doclibrary_docs.created_at DESC"
    end

    item.join 'INNER JOIN doclibrary_view_acl_docs ON doclibrary_docs.id = doclibrary_view_acl_docs.id'
    item.page params[:page], params[:limit]
    select = "doclibrary_docs.id, doclibrary_docs.state, doclibrary_docs.updated_at, doclibrary_docs.latest_updated_at, "
    select += "doclibrary_docs.parent_id, doclibrary_docs.section_code, doclibrary_docs.title, doclibrary_docs.title_id, doclibrary_docs.category1_id"
    @items = item.find(:all, :select => select).group('doclibrary_docs.id')
  end

  def category_ids_narrow_down
    cats = []
    unless params[:cat].blank?
      item = doclib_db_alias(Doclibrary::Folder)
      item = item.new
      item.and :title_id, @title.id
      item.and :state, 'public'
      item.and :id, params[:cat]
      items = item.find(:all, :select => 'id')
      cats += category_narrow(items) if items
    end
    cats
  end

  def category_narrow(items)
    cats = []
    items.each do |item|
      cats << item.id
      cats += category_narrow(item.children.find(:all, :conditions => {:state => 'public'}))
    end
    cats
  end

  def search_index_docs
    item = doclib_db_alias(Doclibrary::Doc)
    item = item.new
    item.and :state, 'public'
    item.and :title_id, params[:title_id]
    item.search params
    item.page   params[:page], params[:limit]
    @items = item.find(:all, :order => "inpfld_001 , inpfld_002 DESC, inpfld_003, inpfld_004, inpfld_005, inpfld_006")
  end

  def normal_category_index
    category_folder_items unless doc_searching?

    if @title.form_name == 'form002'
      normal_category_index_form002
    else
      normal_category_index_form001
    end
  end

  def category_folder_items(state=nil)
    item = doclib_db_alias(Doclibrary::Folder)
    folder = item.find_by_id(params[:cat])

    if folder.blank?
      level_no = 2
      parent_id = 1
    else
      level_no = folder.level_no + 1
      parent_id = folder.id
    end

    item = doclib_db_alias(Doclibrary::ViewAclFolder)
    item = item.new
    item.id = nil
    item.and :state, (state == 'draft' ? 'closed' : 'public')
    item.and :title_id, @title.id
    item.and :level_no, level_no unless state == 'draft'
    item.and :parent_id, parent_id unless state == 'draft'
    item.and {|d|
      d.or {|d2|
        d2.and :acl_flag, 0
      }
      if @is_admin
        d.or {|d2|
          d2.and :acl_flag, 9
        }
      else
        d.or {|d2|
          d2.and :acl_flag, 1
          d2.and :acl_section_id, Site.user.user_group_parent_ids
        }
        d.or {|d2|
          d2.and :acl_flag, 2
          d2.and :acl_user_id, Site.user.id
        }
      end
    }
    item.order "level_no, sort_no, id"
    item.page params[:page], params[:limit]
    @folders = item.find(:all).group(:id)
  end

  def normal_category_index_form002
    item = doclib_db_alias(Doclibrary::Doc)
    item = item.new
    item.and :state, 'public'
    item.and :title_id, @title.id
    item.and :category1_id, params[:cat]
    item.page params[:page], params[:limit]
    @items = item.find(:all, :order => "inpfld_001, inpfld_002 DESC, inpfld_003 DESC, inpfld_004 DESC, inpfld_005, inpfld_006")
  end

  def normal_draft_index
    user_groups = Site.user.enable_user_groups
    user_groups_code = user_groups.map{|group| group.group_code} unless user_groups.blank?
    item = doclib_db_alias(Doclibrary::Doc)
    item = item.new
    item.and 'doclibrary_docs.title_id', @title.id
    item.and 'doclibrary_docs.state', 'draft'
    item.and 'doclibrary_docs.section_code', user_groups_code unless user_groups_code.blank? unless @is_admin
    item.and item.get_keywords_condition(params[:kwd], :title, :body) unless params[:kwd].blank?
    item.and item.get_creator_condition(params[:creator], :creater, :createrdivision_id) unless params[:creator].blank?
    item.and(
        item.get_date_condition(params[:term_start],
        'doclibrary_docs.created_at', {:is_term_start => true})) if params[:term_start].present?
    item.and(
        item.get_date_condition(params[:term_finish],
        'doclibrary_docs.created_at', {:is_term_start => false})) if params[:term_finish].present?
    item.and {|d|
      d.or {|d2|
        d2.and 'doclibrary_view_acl_docs.acl_flag', 0
        d2.and 'doclibrary_view_acl_folders.state', "public"
      }
      if @is_admin
        d.or {|d2|
          d2.and 'doclibrary_view_acl_docs.acl_flag', 9
          d2.and 'doclibrary_view_acl_folders.state', "public"
        }
      else
        d.or {|d2|
          d2.and 'doclibrary_view_acl_docs.acl_flag', 1
          d2.and 'doclibrary_view_acl_docs.acl_section_code', Site.parent_user_groups.map{|g| g.code}
          d2.and 'doclibrary_view_acl_folders.state', "public"
        }
        d.or {|d2|
          d2.and 'doclibrary_view_acl_docs.acl_flag', 2
          d2.and 'doclibrary_view_acl_docs.acl_user_code', Site.user.code
          d2.and 'doclibrary_view_acl_folders.state', "public"
        }
      end
    }
    item.join 'INNER JOIN doclibrary_view_acl_docs ON doclibrary_docs.id = doclibrary_view_acl_docs.id INNER JOIN doclibrary_view_acl_folders ON doclibrary_docs.category1_id = doclibrary_view_acl_folders.id'
    item.order "doclibrary_docs.updated_at DESC, doclibrary_docs.created_at DESC, doclibrary_view_acl_docs.sort_no, doclibrary_docs.category1_id, doclibrary_docs.title"
    item.page params[:page], params[:limit]
    select = "DISTINCT doclibrary_docs.id, doclibrary_docs.state, doclibrary_docs.updated_at, doclibrary_docs.latest_updated_at, "
    select += "doclibrary_docs.parent_id, doclibrary_docs.section_code, doclibrary_docs.title, doclibrary_docs.title_id, doclibrary_docs.category1_id"
    @items = item.find(:all, :select => select).group('doclibrary_docs.id')
  end

  def recognize_index
    item = doclib_db_alias(Doclibrary::Doc)
    item = item.new
    item.and 'doclibrary_docs.title_id', @title.id
    item.and "doclibrary_docs.state", 'recognize'
    item.and item.get_keywords_condition(params[:kwd], :title, :body) unless params[:kwd].blank?
    item.and item.get_creator_condition(params[:creator], :creater, :createrdivision_id) unless params[:creator].blank?
    item.and(
        item.get_date_condition(params[:term_start],
        'doclibrary_docs.created_at', {:is_term_start => true})) if params[:term_start].present?
    item.and(
        item.get_date_condition(params[:term_finish],
        'doclibrary_docs.created_at', {:is_term_start => false})) if params[:term_finish].present?
    item.and {|d|
      d.or {|d2|
        d2.and 'doclibrary_view_acl_docs.acl_flag', 0
        d2.and 'doclibrary_view_acl_folders.state', "public" 
      }
      if @is_admin
        d.or {|d2|
          d2.and 'doclibrary_view_acl_docs.acl_flag', 9
          d2.and 'doclibrary_view_acl_folders.state', "public" 
        }
      else
        d.or {|d2|
          d2.and 'doclibrary_view_acl_docs.acl_flag', 1
          d2.and 'doclibrary_view_acl_docs.acl_section_code', Site.parent_user_groups.map{|g| g.code}
          d2.and 'doclibrary_view_acl_folders.state', "public" 
        }
        d.or {|d2|
          d2.and 'doclibrary_view_acl_docs.acl_flag', 2
          d2.and 'doclibrary_view_acl_docs.acl_user_code', Site.user.code
          d2.and 'doclibrary_view_acl_folders.state', "public" 
        }
      end
    }
    unless @is_admin
      item.and {|d|
        user_groups = Site.user.enable_user_groups
        user_groups_code = user_groups.map{|group| group.group_code} unless user_groups.blank?
        d.or "doclibrary_docs.section_code", user_groups_code unless user_groups_code.blank?
        d.or "doclibrary_recognizers.code", Site.user.code
        d.or "doclibrary_docs.creater_id", Site.user.code
      }
    end
    item.join "INNER JOIN doclibrary_recognizers ON " +
        "doclibrary_docs.id = doclibrary_recognizers.parent_id AND " +
        "doclibrary_docs.title_id = doclibrary_recognizers.title_id " +
        "INNER JOIN doclibrary_view_acl_folders ON " +
        "doclibrary_docs.category1_id = doclibrary_view_acl_folders.id " +
        "INNER JOIN doclibrary_view_acl_docs ON " +
        "doclibrary_docs.id = doclibrary_view_acl_docs.id"
    item.group_by 'doclibrary_docs.id'
    item.order 'latest_updated_at DESC'
    item.page params[:page], params[:limit]
    select = "DISTINCT doclibrary_docs.id, doclibrary_docs.state, doclibrary_docs.updated_at, doclibrary_docs.latest_updated_at, "
    select += "doclibrary_docs.parent_id, doclibrary_docs.section_code, doclibrary_docs.title, doclibrary_docs.title_id, doclibrary_docs.category1_id"
    @items = item.find(:all, :select => select).group('doclibrary_docs.id')
  end

  def recognized_index
    item = doclib_db_alias(Doclibrary::Doc)
    item = item.new
    item.and 'doclibrary_docs.title_id', @title.id
    item.and 'doclibrary_docs.state', 'recognized'
    user_groups = Site.user.enable_user_groups
    user_groups_code = user_groups.map{|group| group.group_code} unless user_groups.blank?
    item.and "doclibrary_docs.section_code", user_groups_code unless user_groups_code.blank? unless @is_admin
    item.and item.get_keywords_condition(params[:kwd], :title, :body) unless params[:kwd].blank?
    item.and item.get_creator_condition(params[:creator], :creater, :createrdivision_id) unless params[:creator].blank?
    item.and(
        item.get_date_condition(params[:term_start],
        'doclibrary_docs.created_at', {:is_term_start => true})) if params[:term_start].present?
    item.and(
        item.get_date_condition(params[:term_finish],
        'doclibrary_docs.created_at', {:is_term_start => false})) if params[:term_finish].present?
    item.and {|d|
      d.or {|d2|
        d2.and 'doclibrary_view_acl_docs.acl_flag', 0
        d2.and 'doclibrary_view_acl_folders.state', "public"
      }
      if @is_admin
        d.or {|d2|
          d2.and 'doclibrary_view_acl_docs.acl_flag', 9
          d2.and 'doclibrary_view_acl_folders.state', "public"
        }
      else
        d.or {|d2|
          d2.and 'doclibrary_view_acl_docs.acl_flag', 1
          d2.and 'doclibrary_view_acl_docs.acl_section_code', Site.parent_user_groups.map{|g| g.code}
          d2.and 'doclibrary_view_acl_folders.state', "public"
        }
        d.or {|d2|
          d2.and 'doclibrary_view_acl_docs.acl_flag', 2
          d2.and 'doclibrary_view_acl_docs.acl_user_code', Site.user.code
          d2.and 'doclibrary_view_acl_folders.state', "public"
        }
      end
    }
    item.join 'inner join doclibrary_view_acl_docs on doclibrary_docs.id = doclibrary_view_acl_docs.id INNER JOIN doclibrary_view_acl_folders ON doclibrary_docs.category1_id = doclibrary_view_acl_folders.id'
    item.order "doclibrary_docs.updated_at DESC, doclibrary_docs.created_at DESC, doclibrary_view_acl_docs.sort_no, doclibrary_docs.category1_id, doclibrary_docs.title"
    item.page params[:page], params[:limit]
    select = "DISTINCT doclibrary_docs.id, doclibrary_docs.state, doclibrary_docs.updated_at, doclibrary_docs.latest_updated_at, "
    select += "doclibrary_docs.parent_id, doclibrary_docs.section_code, doclibrary_docs.title, doclibrary_docs.title_id, doclibrary_docs.category1_id"
    @items = item.find(:all, :select => select).group('doclibrary_docs.id')
  end

  def normal_draft_index_form002
    item = doclib_db_alias(Doclibrary::Folder)
    folder = item.find_by_id(params[:cat])

    params[:cat] = 1 if folder.blank?
    level_no = 2 if folder.blank?
    parent_id = 1 if folder.blank?

    level_no = folder.level_no + 1 unless folder.blank?
    parent_id = folder.id unless folder.blank?

    item = doclib_db_alias(Doclibrary::Folder)
    item = item.new
    item.and :state, 'public'
    item.and :title_id, @title.id
    item.and :level_no, level_no
    item.and :parent_id, parent_id
    item.page   params[:page], params[:limit]
    @folders = item.find(:all, :order=>"level_no, sort_no, id")

    str_order = "updated_at DESC, created_at DESC, category1_id, id" unless @title.form_name == 'form002'
    str_order = "inpfld_001 , inpfld_002 DESC, inpfld_003, inpfld_004, inpfld_005, inpfld_006" if @title.form_name == 'form002'
    item = doclib_db_alias(Doclibrary::Doc)
    item = item.new
    item.and :state, 'draft'
    item.and :title_id, @title.id
    item.and :category1_id, params[:cat]
    item.page   params[:page], params[:limit]
    @items = item.find(:all, :order => str_order)
  end

  def set_folder_level_code

    item = doclib_db_alias(Doclibrary::GroupFolder)
    item = item.new
    item.and :title_id, @title.id
    item.and :level_no, 1
    item.and :state, 'public'
    items = item.find(:all,:order => 'level_no, sort_no, parent_id, id')
    @group_levels = []
    set_folder_hash('group', items)

    item = doclib_db_alias(Doclibrary::Folder)
    item = item.new
    item.and :title_id, @title.id
    item.and :level_no, 1
    items = item.find(:all,:order => 'level_no, sort_no, parent_id, id')
    @category_levels = []
    set_folder_hash('category', items)
    Doclibrary::GroupFolder.remove_connection

    # 管理権限なしフォルダのID取得
    @without_admin_folders = Doclibrary::Folder.without_admin_auth(@title.id)
  end

  def set_folder_hash(mode, items)
    if items.size > 0
      items.each do |item|
        if item.state == 'public'
          tree = '+'
          tree += "-" * (item.level_no - 2) if 0 < (item.level_no - 2)
          @group_levels << [tree + item.code + item.name, item.code] if mode == 'group'
          @category_levels << [tree + item.name, item.id] if 1 <= item.level_no unless mode == 'group'
          case mode
          when 'group'
            children = item.children
          when 'category'
            children = item.readable_public_children(@is_admin)
          end
          set_folder_hash(mode, children)
        end
      end
    end
  end

  def section_folder_state_update
    group_item = doclib_db_alias(Doclibrary::GroupFolder)
    item = doclib_db_alias(Doclibrary::Doc)
    item = item.new
    item.and :state, 'public'
    item.and :title_id, @title.id
    item.find(:all, :select=>'section_code', :group => 'section_code').each do |code|
      g_item = group_item.new
      g_item.and :title_id, @title.id
      g_item.and :code, code.section_code
      g_item.find(:all).each do |group|
        group_state_rewrite(group,group_item)
      end
    end

  end

  def group_state_rewrite(item,group_item)
    group_item.update(item.id, :state =>'public')
    unless item.parent.blank?
      group_state_rewrite(item.parent, group_item)
    end
  end

  def form002_categories
    if @title.form_name == 'form002'
      @documents = []
      item = doclib_db_alias(Doclibrary::Category)
      item.find(:all, :conditions => {:state => 'public', :title_id => @title.id}, :order => 'id DESC').each do |dep|
        if dep.sono2.blank?
          str_sono = dep.sono.to_s
        else
          str_sono = "#{dep.sono.to_s} - #{dep.sono2.to_s}"
        end
        @documents << ["#{dep.wareki}#{dep.nen}年#{dep.gatsu}月その#{str_sono} : #{dep.filename}", dep.id]
      end
      Doclibrary::Category.remove_connection
    end
  end


  def set_form002_params
      item = doclib_db_alias(Doclibrary::Category)
      item = item.new
      item.and :id, @item.category2_id
      item = item.find(:first)
      if item
        @item.inpfld_001 = item.wareki
        @item.inpfld_002 = item.nen
        @item.inpfld_003 = item.gatsu
        @item.inpfld_004 = item.sono
        @item.inpfld_005 = item.sono2

        @item.inpfld_007 = "#{@item.inpfld_004.to_s} - #{item.sono2}" unless item.sono2.blank?
        @item.inpfld_007 = item.sono if item.sono2.blank?
      end
      Doclibrary::Category.remove_connection
  end

  def is_attach_new
    ret = false
    case @title.upload_system
    when 1..4
      ret = true
    end
    return ret
  end

  def return_form002_attached_url
    check = is_attach_new
    ret = ''
    item = doclib_db_alias(Doclibrary::File)
    item = item.new
    item.and :title_id, @item.title_id
    item.and :parent_id, @item.category2_id
    file = item.find(:first)
    unless file.blank?
      ret = "#{file.file_uri(file.system_name)}" if check
      ret = "/_admin/gwboard/receipts/#{file.id}/download_object?system=#{file.system_name}&title_id=#{file.title_id}" unless check
    end
    Doclibrary::File.remove_connection
    return ret
  end

  def set_recogusers
    @select_recognizers = {"1"=>'',"2"=>'',"3"=>'',"4"=>'',"5"=>''}
    i = 0
    for recoguser in @recogusers
      i += 1
      @select_recognizers[i.to_s] = recoguser.user_id.to_s
    end
  end

  def get_recogusers
    item = doclib_db_alias(Doclibrary::Recognizer)
    item = item.new
    item.and :title_id, @title.id
    item.and :parent_id, params[:id]
    item.order 'id'
    @recogusers = item.find(:all)
    Doclibrary::Recognizer.remove_connection
  end

  def publish_update
    item = doclib_db_alias(Doclibrary::Doc)
    item = item.new
    item.and :state, 'recognized'
    item.and :title_id, @title.id
    item.and :id, params[:id]

    item = item.find(:first)
    if item
      item.state = 'public'
      item.published_at = Time.now
      item.save
    end

    # 作成者、または承認者が公開処理を行った場合、
    # 作成者への承認完了の新着情報を既読にする
    item.seen_approve_remind

    Doclibrary::Doc.remove_connection
    redirect_to(doclibrary_docs_path({:title_id=>@title.id}))
  end

  def recognize_update
    item = doclib_db_alias(Doclibrary::Recognizer)
    item = item.new
    item.and :title_id, @title.id
    item.and :parent_id, params[:id]
    item.and :code, Site.user.code
    item = item.find(:first)
    if item
      item.recognized_at = Time.now
      item.save
    end

    item = doclib_db_alias(Doclibrary::Recognizer)
    item = item.new
    item.and :title_id, @title.id
    item.and :parent_id, params[:id]
    item.and "sql", "recognized_at IS NULL"
    item = item.find(:all)
    recognizer_count = item.length
    Doclibrary::Recognizer.remove_connection

    item = doclib_db_alias(Doclibrary::Doc)
    item = item.find(params[:id])
    @parent = item.parent

    # 承認依頼の新着情報を既読にする
    item.seen_request_remind(Site.user.id)

    if recognizer_count == 0
      item.state = 'recognized'
      item.recognized_at = Time.now
      item.save

      # 承認者全員が承認した場合、承認完了の新着情報を作成する
      item.build_approve_remind

      user = System::User.find_by_code(item.editor_id.to_s)
      unless user.blank?
        Gw.add_memo(user.id.to_s, "#{@title.title}「#{item.title}」について、全ての承認が終了しました。", "次のボタンから記事を確認し,公開作業を行ってください。<br /><a href='#{doclibrary_show_uri(item,params)}&state=PUBLISH'><img src='/_common/themes/gw/files/bt_openconfirm.gif' alt='公開処理へ' /></a>",{:is_system => 1})
      end
    end

    Doclibrary::Doc.remove_connection
    get_role_new

    redirect_to_url = "#{doclibrary_docs_path({:title_id=>@title.id})}"
    if @parent.admin_user?
      redirect_to_url += "&state=RECOGNIZE"
    end
    redirect_to(redirect_to_url)
  end

  def check_recognize
    item = doclib_db_alias(Doclibrary::Recognizer)
    item = item.new
    item.and :title_id, @title.id
    item.and :parent_id, params[:id]
    item.and :code, Site.user.code
    item.and 'sql', "recognized_at is null"
    item = item.find(:all)
    ret = nil
    ret = true if item.length != 0
    Doclibrary::Recognizer.remove_connection
    return ret
  end

  def check_recognize_readable
    item = doclib_db_alias(Doclibrary::Recognizer)
    item = item.new
    item.and :title_id, @title.id
    item.and :parent_id, params[:id]
    item.and :code, Site.user.code
    item = item.find(:all)
    ret = nil
    ret = true if item.length != 0
    Doclibrary::Recognizer.remove_connection
    return ret
  end


  def sql_where
    sql = Condition.new
    sql.and :parent_id, @item.id
    sql.and :title_id, @item.title_id
    return sql.where
  end

  def destroy_atacched_files
    item = doclib_db_alias(Doclibrary::File)
    item.destroy_all(sql_where)
    Doclibrary::File.remove_connection
  end

  def destroy_files
    item = doclib_db_alias(Doclibrary::DbFile)
    item.destroy_all(sql_where)
    Doclibrary::DbFile.remove_connection
  end

  # === 検索結果一覧画面かどうかの判定メソッド
  #  検索結果一覧画面かどうかを判定するメソッドである。
  #  判定方法は検索項目に入力データがあるかどうかで判定する。
  # ==== 引数
  #  なし
  # ==== 戻り値
  #  検索結果一覧画面の場合はTrue、検索結果一覧画面でない場合Falseを戻す
  def doc_searching?
    return true if params[:kwd].present?
    return true if params[:creator].present?
    return true if params[:term_start].present?
    return true if params[:term_finish].present?
    return false
  end

  # === ファイル一括ダウンロード用メソッド
  #  本メソッドは、ファイルを一括ダウンロードするメソッドである。
  # ==== 引数
  #  なし
  # ==== 戻り値
  #  なし
  def export_zip_file
    # ファイルが選択されていない場合、例外を発生して終了
    if params[:file_check].blank?
      raise I18n.t('rumi.doclibrary.message.attached_file_not_selected')
    end
    
    # 現在選択中のファイルID配列
    selected_file_id = params[:file_check].map{|id| id.to_i}
    
    # 選択されたファイルを取得
    files_item = doclib_db_alias(Doclibrary::Doc)
    files_item = files_item.new
    files_item.and 'doclibrary_docs.title_id', @title.id
    files_item.and 'doclibrary_docs.id', 'IN', selected_file_id
    files = files_item.find(:all)
    
    # zipファイル情報取得
    zip_data = {}
    for file in files
      # 分類フォルダと同じフォルダ階層を取得
      Doclibrary::Folder.remove_connection
      parent_item = doclib_db_alias(Doclibrary::Folder)
      parent = parent_item.find_by_id(file.category1_id)
      tree = parent.parent_tree.map{|value| "#{value.id.to_s}_#{value.name}"}
      tree_path = File.join(tree)
      
      # フォルダ階層の末尾に「ファイルID_ファイル名」フォルダを追加
      tree_path = File.join(tree_path, "#{file.id.to_s}_#{file.title}")
      
      # ファイルに登録されている添付ファイルを取得
      attache_file_item = doclib_db_alias(Doclibrary::File)
      attache_file_item = attache_file_item.new
      attache_file_item.and :title_id, @title.id
      attache_file_item.and :parent_id, file.id
      attache_file_item.order 'id'
      attache_files = attache_file_item.find(:all)
      
      if attache_files.count == 0
        # 添付ファイルが未登録の場合、zipファイルへフォルダのみ作成する
        # zipファイル情報の保存
        zip_data[tree_path] = ''
      else
        # zipファイルへフォルダと添付ファイルを作成する
        for attache_file in attache_files
          # zipファイル情報の保存
          zip_data[File.join(tree_path, "#{attache_file.id}_#{attache_file.filename}")] =
              attache_file.f_name
        end
      end
    end

    # 一時フォルダの存在チェックとフォルダ作成
    unless File.exist?(Rumi::Doclibrary::ZipFileUtils::TMP_FILE_PATH)
      FileUtils.mkdir_p(Rumi::Doclibrary::ZipFileUtils::TMP_FILE_PATH)
    end

    # 一時ファイル名
    target_zip_file = File.join(
        Rumi::Doclibrary::ZipFileUtils::TMP_FILE_PATH,
        "#{request.session_options[:id]}.zip")
    
    # zipファイルの作成
    Rumi::Doclibrary::ZipFileUtils.zip(
        target_zip_file,
        zip_data,
        {:fs_encoding => Rumi::Doclibrary::ZipFileUtils::ZIP_ENCODING})
    
    # ダウンロードファイル名
    download_file_name = "doclibrary_#{Time.now.strftime('%Y%m%d%H%M%S')}.zip"
    send_file target_zip_file ,
        :filename => download_file_name if FileTest.exist?(target_zip_file)
    # 一時ファイルの削除
    #File.delete target_zip_file if FileTest.exist?(target_zip_file)
    
    Doclibrary::Doc.remove_connection
    Doclibrary::Folder.remove_connection
    Doclibrary::File.remove_connection
  end

  # === ファイルドラッグ＆ドロップ（移動/コピー）用メソッド
  #  本メソッドは、ファイルをドラッグ＆ドロップ（移動/コピー）するメソッドである。
  # ==== 引数
  #  なし
  # ==== 戻り値
  #  なし
  def files_drag
    begin
      # 移動（コピー）元ファイルIDの取得
      file_ids = params[:item][:ids].split(",")
      raise if file_ids.blank?

      # 移動（コピー）先フォルダIDの取得
      folder_id = params[:item][:folder]
      raise if folder_id.blank?

      # ファイル／フォルダ操作（移動/コピー）の取得
      drag_option = (params[:drag_option].blank?)? 0 : params[:drag_option].to_i

      if drag_option == 1
        error_message = I18n.t('rumi.doclibrary.drag_and_drop.message.file_copy_error')

        # ファイルコピー
        file_ids.each do |file_id|
          copy_file(file_id, folder_id)
        end

        # 添付ファイルの使用容量の更新（DB更新の有無に関わらず実行）
        update_total_file_size

        # ファイルコピー完了メッセージ
        flash[:file_drag_message] = I18n.t('rumi.doclibrary.drag_and_drop.message.copy_file')
      else
        error_message = I18n.t('rumi.doclibrary.drag_and_drop.message.file_move_error')

        # ファイル移動
        file_ids.each do |file_id|
          move_file(file_id, folder_id)
        end

        # ファイル移動完了メッセージ
        flash[:file_drag_message] = I18n.t('rumi.doclibrary.drag_and_drop.message.move_file')
      end
    rescue => ex
      if ex.message.length == 0
        flash[:file_drag_message] = error_message
      else
        flash[:file_drag_message] = ex.message
      end
    end

    return redirect_to(doclibrary_docs_path({:title_id=>@title.id}) + doclib_params_set)
  end

  # === フォルダドラッグ＆ドロップ（移動、コピー）用メソッド
  #  本メソッドは、ファイルをドラッグ＆ドロップ（移動、コピー）するメソッドである。
  # ==== 引数
  #  なし
  # ==== 戻り値
  #  なし
  def folder_drag
    begin
      # 移動（コピー）対象フォルダIDの取得
      src_folder_id = params[:item][:src_folder]
      raise if src_folder_id.blank?

      # 移動（コピー）先フォルダIDの取得
      dst_folder_id = params[:item][:dst_folder]
      raise if dst_folder_id.blank?

      # ファイル／フォルダ操作（移動/コピー）の取得
      drag_option = (params[:drag_option].blank?)? 0 : params[:drag_option].to_i

      if drag_option == 1
        error_message = I18n.t('rumi.doclibrary.drag_and_drop.message.folder_copy_error')

        # フォルダコピー
        copy_folder(src_folder_id, dst_folder_id)

        # 添付ファイルの使用容量の更新（DB更新の有無に関わらず実行）
        update_total_file_size

        # フォルダコピー完了メッセージ
        flash[:folder_drag_message] = I18n.t('rumi.doclibrary.drag_and_drop.message.copy_folder')
      else
        error_message = I18n.t('rumi.doclibrary.drag_and_drop.message.folder_move_error')

        # フォルダ移動
        move_folder(src_folder_id, dst_folder_id)

        # フォルダ移動完了メッセージ
        flash[:folder_drag_message] = I18n.t('rumi.doclibrary.drag_and_drop.message.move_folder')
      end
    rescue => ex
      if ex.message.length == 0
        flash[:folder_drag_message] = error_message
      else
        flash[:folder_drag_message] = ex.message
      end
    end

    return redirect_to(doclibrary_docs_path({:title_id=>@title.id}) + doclib_params_set)
  end

  # === 添付ファイル利用容量更新メソッド
  #  本メソッドは、添付ファイル、画像ファイルの利用容量を更新するメソッドである。
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def update_total_file_size
    doclibrary_folder_cnn = doclib_db_alias(Doclibrary::File)
    total = doclibrary_folder_cnn.sum(:size,:conditions => 'unid = 1')
    total = 0 if total.blank?
    @title.upload_graphic_file_size_currently = total.to_f

    total = doclibrary_folder_cnn.sum(:size,:conditions => 'unid = 2')
    total = 0 if total.blank?
    @title.upload_document_file_size_currently = total.to_f

    @title.save
    Doclibrary::File.remove_connection
  end


protected

  # === ファイル移動メソッド
  #  本メソッドは、ファイルを移動するメソッドである。
  # ==== 引数
  #  * file_id: ファイルID
  #  * folder_id: 移動先フォルダID
  # ==== 戻り値
  #  なし
  def move_file(file_id, folder_id)
    doclibrary_folder_cnn = doclib_db_alias(Doclibrary::Folder)
    doclibrary_doc_cnn = doclib_db_alias(Doclibrary::Doc)
    doclibrary_file_cnn = doclib_db_alias(Doclibrary::File)
    begin
      # 移動元ファイルの取得
      src_file = doclibrary_doc_cnn.find_by_id(file_id)
      if src_file.blank?
        raise I18n.t('rumi.doclibrary.drag_and_drop.message.src_move_file_not_found')
      end

      # ファイルの移動先フォルダが現在のフォルダの場合、終了
      if src_file.category1_id == folder_id.to_i
        raise I18n.t('rumi.doclibrary.drag_and_drop.message.no_movement')
      end

      # 移動元フォルダの取得
      src_folder = doclibrary_folder_cnn.find_by_id(src_file.category1_id)
      if src_folder.blank?
        raise I18n.t('rumi.doclibrary.drag_and_drop.message.src_move_folder_not_found')
      end

      # 移動先フォルダの取得
      dst_folder = doclibrary_folder_cnn.find_by_id(folder_id)
      if dst_folder.blank?
        raise I18n.t('rumi.doclibrary.drag_and_drop.message.dst_move_folder_not_found')
      end

      # 移動元フォルダ、移動先フォルダへの管理権限があるかをチェック
      unless src_folder.admin_user?(Site.user.id) &&
          dst_folder.admin_user?(Site.user.id)
        raise I18n.t('rumi.doclibrary.drag_and_drop.message.no_authority_to_edit_folder')
      end

      begin
        doclibrary_doc_cnn.transaction do
          begin
            doclibrary_file_cnn.transaction do
              begin
                # == ファイル移動 ==
                # ファイル情報変更
                src_file.category1_id = folder_id
                # 更新者情報変更
                src_file.editdate = Time.now.strftime("%Y-%m-%d %H:%M")
                src_file.editor = Site.user.name unless Site.user.name.blank?
                src_file.editordivision =
                    Site.user_group.name unless Site.user_group.name.blank?
                src_file.editor_id = Site.user.code unless Site.user.code.blank?
                src_file.editordivision_id = 
                    Site.user_group.code unless Site.user_group.code.blank?
                src_file.editor_admin = (@is_admin)? true : false
                src_file.latest_updated_at = Time.now
                src_file.save!

                # 移動ファイルの添付ファイル情報を取得
                attach_files =
                    doclibrary_file_cnn.find(:all,
                                             :conditions => "parent_id = #{src_file.id}")
                # 添付ファイルについて情報変更
                attach_files.each do |attach_file|
                  attach_file.updated_at = Time.now
                  attach_file.save!
                end
              end
            end
          rescue
            raise # エラーメッセージは上位メソッドで表示
          end
        end
      rescue
        raise # エラーメッセージは上位メソッドで表示
      end
    rescue => ex
      raise ex.message
    ensure
      Doclibrary::Folder.remove_connection
      Doclibrary::Doc.remove_connection
      Doclibrary::File.remove_connection
    end
  end

  # === ファイルコピーメソッド
  #  本メソッドは、ファイルをコピーするメソッドである。
  # ==== 引数
  #  * file_id: ファイルID
  #  * folder_id: コピー先フォルダID
  #  * is_folder_copy: フォルダーコピー処理中のファイルコピーか？（True:フォルダーコピー / False:ファイルコピー）
  # ==== 戻り値
  #  なし
  def copy_file(file_id, folder_id, is_folder_copy=false)
    doclibrary_folder_cnn = doclib_db_alias(Doclibrary::Folder)
    doclibrary_doc_cnn = doclib_db_alias(Doclibrary::Doc)
    doclibrary_file_cnn = doclib_db_alias(Doclibrary::File)
    begin
      # コピー元ファイルの取得
      src_file = doclibrary_doc_cnn.find_by_id(file_id)
      if src_file.blank?
        raise I18n.t('rumi.doclibrary.drag_and_drop.message.src_copy_file_not_found')
      end

      # コピー元フォルダの取得
      src_folder = doclibrary_folder_cnn.find_by_id(src_file.category1_id)
      if src_folder.blank?
        raise I18n.t('rumi.doclibrary.drag_and_drop.message.src_copy_folder_not_found')
      end

      # コピー先フォルダの取得
      folder = doclibrary_folder_cnn.find_by_id(folder_id)
      if folder.blank?
        raise I18n.t('rumi.doclibrary.drag_and_drop.message.dst_copy_folder_not_found')
      end

      # コピー元フォルダへの管理権限があるかをチェック
      unless src_folder.admin_user?(Site.user.id)
        raise I18n.t('rumi.doclibrary.drag_and_drop.message.no_authority_to_edit_folder')
      end

      # コピー先フォルダへの管理権限があるかをチェック
      unless folder.admin_user?(Site.user.id)
        raise I18n.t('rumi.doclibrary.drag_and_drop.message.no_authority_to_edit_folder')
      end

      # 現在の添付ファイル、画像ファイルの利用容量チェック
      if @title.is_disk_full_for_document_file? || @title.is_disk_full_for_graphic_file?
        raise I18n.t('rumi.doclibrary.drag_and_drop.message.has_exceeded_capacity')
      end

      begin
        doclibrary_doc_cnn.transaction do
          begin
            doclibrary_file_cnn.transaction do
              begin
                # == ファイルコピー ==
                copy_file = doclibrary_doc_cnn.new
                copy_file.attributes = src_file.attributes
                # フォルダ情報変更
                unless is_folder_copy
                  copy_file.title = "#{copy_file.title} - コピー"
                end
                copy_file.category1_id = folder_id
                # 作成日、更新日リセット
                copy_file.created_at = nil
                copy_file.updated_at = nil
                copy_file.latest_updated_at = Time.now
                # 作成者情報変更
                copy_file.createdate = Time.now.strftime("%Y-%m-%d %H:%M")
                copy_file.creater_id = Site.user.code unless Site.user.code.blank?
                copy_file.creater = Site.user.name unless Site.user.name.blank?
                copy_file.createrdivision = 
                    Site.user_group.name unless Site.user_group.name.blank?
                copy_file.createrdivision_id = 
                    Site.user_group.code unless Site.user_group.code.blank?
                copy_file.creater_admin = (@is_admin)? true : false
                # 更新者情報リセット
                copy_file.editdate = nil
                copy_file.editor = nil
                copy_file.editordivision = nil
                copy_file.editor_id = Site.user.code unless Site.user.code.blank?
                copy_file.editordivision_id = 
                    Site.user_group.code unless Site.user_group.code.blank?
                copy_file.editor_admin = (@is_admin)? true : false
                copy_file.save!

                # 添付ファイル情報コピー
                src_file.attach_files.each do |attach|
                  attributes = attach.attributes.reject do |key, value|
                    key == 'id' || key == 'parent_id'
                  end
                  attach_file = copy_file.attach_files.build(attributes)
                  attach_file.created_at = Time.now
                  attach_file.updated_at = Time.now

                  # 添付ファイルの存在チェック
                  unless File.exist?(attach.f_name)
                    raise I18n.t('rumi.doclibrary.drag_and_drop.message.attached_file_not_found')
                  end
                  upload = ActionDispatch::Http::UploadedFile.new({
                    :filename => attach.filename,
                    :content_type => attach.content_type,
                    :tempfile => File.open(attach.f_name)
                  })
                  attach_file._upload_file(upload)
                  attach_file.save!
                end

                # 承認者情報コピー
                src_file.recognizers.each do |recognizer|
                  attributes = recognizer.attributes.reject do |key, value|
                    key == 'id' || key == 'parent_id'
                  end
                  copy_file.recognizers.build(attributes).save!
                end
              end
            end
          rescue
            raise # エラーメッセージは上位メソッドで表示
          end
        end
      rescue
        raise # エラーメッセージは上位メソッドで表示
      end
    rescue => ex
      raise ex.message
    ensure
      Doclibrary::Folder.remove_connection
      Doclibrary::Doc.remove_connection
      Doclibrary::File.remove_connection
    end
  end

  # === フォルダ移動メソッド
  #  本メソッドは、フォルダを移動するメソッドである。
  # ==== 引数
  #  * src_folder_id: 移動対象フォルダID
  #  * dst_folder_id: 移動先フォルダID
  # ==== 戻り値
  #  なし
  def move_folder(src_folder_id, dst_folder_id)
    doclibrary_folder_cnn = doclib_db_alias(Doclibrary::Folder)
    doclibrary_doc_cnn = doclib_db_alias(Doclibrary::Doc)
    doclibrary_file_cnn = doclib_db_alias(Doclibrary::File)
    begin
      # 移動対象フォルダの取得
      src_folder = doclibrary_folder_cnn.find_by_id(src_folder_id)
      if src_folder.blank?
        raise I18n.t('rumi.doclibrary.drag_and_drop.message.src_move_folder_not_found')
      end

      # 移動先フォルダの取得
      dst_folder = doclibrary_folder_cnn.find_by_id(dst_folder_id)
      if dst_folder.blank?
        raise I18n.t('rumi.doclibrary.drag_and_drop.message.dst_move_folder_not_found')
      end

      # フォルダの移動先フォルダが現在のフォルダの場合、終了
      if src_folder.parent_id == dst_folder.id
        raise I18n.t('rumi.doclibrary.drag_and_drop.message.no_movement')
      end

      # フォルダの移動先フォルダが移動対象フォルダの配下である場合、エラー
      if dst_folder.parent_tree.include?(src_folder)
        raise I18n.t('rumi.doclibrary.drag_and_drop.message.cannot_move_folder')
      end

      # == 移動対象全データ（フォルダ、ファイル、添付ファイル）のID取得（下位フォルダも含む） ==
      # 移動対象全フォルダ
      folder_ids = [src_folder.id]
      folder_ids = src_folder.get_child_folder_ids(folder_ids)

      # 移動対象全ファイル
      file_ids = []
      folder_ids.each do |folder_id|
        files = doclibrary_doc_cnn.find(:all,
                                        :conditions => "category1_id = #{folder_id}")
        files.each do |file|
          file_ids << file.id
        end
      end

      # 移動対象全添付ファイル
      attach_file_ids = []
      file_ids.each do |file_id|
        attach_files = doclibrary_file_cnn.find(:all,
                                        :conditions => "parent_id = #{file_id}")
        attach_files.each do |attach_file|
          attach_file_ids << attach_file.id
        end
      end

      # フォルダ移動
      #
      # ※注意事項
      # 1)複数モデルデータを同時にロールバックさせるため、下記の条件をクリアすること
      #   ・テーブル毎にトランザクションを作成する
      #   ・処理中にDBコネクションを切り替えない（DBコネクションを変数化して使い回す）
      # 2)フォルダ、ファイル、添付ファイルを同時に更新するとlock状態になるため
      #   フォルダ → ファイル → 添付ファイルの順で更新を行う
      begin
        doclibrary_folder_cnn.transaction do
          begin
            doclibrary_doc_cnn.transaction do
              begin
                doclibrary_file_cnn.transaction do
                  begin
                    # 移動フォルダについて権限チェックと情報変更
                    update_move_folder(
                        doclibrary_folder_cnn, src_folder_id, dst_folder_id, 1)

                    # 移動ファイルについて情報変更
                    unless file_ids.blank?
                      doclibrary_doc_cnn.where("id IN (#{file_ids.join(',')})")
                                        .update_all(:editdate => Time.now.strftime("%Y-%m-%d %H:%M"),
                                                    :editor => Site.user.name,
                                                    :editordivision => Site.user_group.name,
                                                    :editor_id => Site.user.code,
                                                    :editordivision_id => Site.user_group.code,
                                                    :editor_admin => (@is_admin)? true : false,
                                                    :updated_at => Time.now,
                                                    :latest_updated_at => Time.now)
                    end

                    # 添付ファイルについて情報変更
                    unless attach_file_ids.blank?
                      doclibrary_file_cnn.where("id IN (#{attach_file_ids.join(',')})")
                                         .update_all(:updated_at => Time.now)
                    end
                  end
                end
              rescue
                raise # エラーメッセージは上位メソッドで表示
              end
            end
          rescue
            raise # エラーメッセージは上位メソッドで表示
          end
        end
      rescue
        raise # エラーメッセージは上位メソッドで表示
      end
    rescue => ex
      raise ex.message
    ensure
      Doclibrary::Folder.remove_connection
      Doclibrary::Doc.remove_connection
      Doclibrary::File.remove_connection
    end
  end

  # === フォルダコピーメソッド
  #  本メソッドは、フォルダコピーするメソッドである。
  # ==== 引数
  #  * src_folder_id: コピー元フォルダID
  #  * dst_folder_id: コピー先フォルダID
  # ==== 戻り値
  #  なし
  def copy_folder(src_folder_id, dst_folder_id)
    doclibrary_folder_cnn = doclib_db_alias(Doclibrary::Folder)
    begin
      # コピー元フォルダの取得
      src_folder = doclibrary_folder_cnn.find_by_id(src_folder_id)
      if src_folder.blank?
        raise I18n.t('rumi.doclibrary.drag_and_drop.message.src_copy_folder_not_found')
      end

      # コピー先フォルダの取得
      dst_folder = doclibrary_folder_cnn.find_by_id(dst_folder_id)
      if dst_folder.blank?
        raise I18n.t('rumi.doclibrary.drag_and_drop.message.dst_copy_folder_not_found')
      end

      # フォルダのコピー先フォルダがコピー元フォルダの配下である場合、エラー
      if dst_folder.parent_tree.include?(src_folder)
        raise I18n.t('rumi.doclibrary.drag_and_drop.message.cannot_move_folder')
      end

      # 現在の添付ファイル、画像ファイルの利用容量チェック
      if @title.is_disk_full_for_document_file? || @title.is_disk_full_for_graphic_file?
        raise I18n.t('rumi.doclibrary.drag_and_drop.message.has_exceeded_capacity')
      end

      # フォルダコピー
      create_copy_folder(src_folder_id, dst_folder_id)
    rescue => ex
      raise ex.message
    ensure
      Doclibrary::Folder.remove_connection
    end
  end

  # === 移動フォルダ更新メソッド
  #  本メソッドは、階層ごとに移動フォルダの情報を更新するメソッドである。
  #
  #   ※注意事項
  #   1)複数モデルデータを同時にロールバックさせるため、下記の条件をクリアすること
  #     ・テーブル毎にトランザクションを作成する
  #     ・処理中にDBコネクションを切り替えない（DBコネクションを変数化して使い回す）
  #   2)フォルダ、ファイル、添付ファイルを同時に更新するとlock状態になるため
  #     フォルダ情報のみ更新し、ファイル、添付ファイルについては後で更新する
  #
  # ==== 引数
  #  * doclibrary_folder_cnn: DBコネクション: DBコネクション（Doclibrary::Folder）
  #  * src_folder_id: 移動対象フォルダID
  #  * dst_folder_id: ドラッグ先フォルダID
  #  * folder_level: フォルダ階層
  # ==== 戻り値
  #  なし
  def update_move_folder(doclibrary_folder_cnn, src_folder_id, dst_folder_id, folder_level)
    begin
      # フォルダ移動のRollbackテスト用コード
      #raise 'フォルダ移動 Rollbackテスト' if folder_level==2

      # 移動対象フォルダの取得
      src_folder = doclibrary_folder_cnn.find_by_id(src_folder_id)
      if src_folder.blank?
        raise I18n.t('rumi.doclibrary.drag_and_drop.message.src_move_folder_not_found')
      end

      # 移動先フォルダの取得
      dst_folder = doclibrary_folder_cnn.find_by_id(dst_folder_id)
      if dst_folder.blank?
        raise I18n.t('rumi.doclibrary.drag_and_drop.message.dst_move_folder_not_found')
      end

      # 移動対象フォルダの親フォルダへの管理権限があるかをチェック
      unless src_folder.parent_folder.admin_user?(Site.user.id)
        raise I18n.t('rumi.doclibrary.drag_and_drop.message.no_authority_to_edit_folder')
      end

      if folder_level == 1
        # 移動先フォルダへの管理権限があるかをチェック
        unless dst_folder.admin_user?(Site.user.id)
          raise I18n.t('rumi.doclibrary.drag_and_drop.message.no_authority_to_edit_folder')
        end

        # 移動フォルダのトップフォルダについて情報変更
        src_folder.parent_id = dst_folder.id
        parent_folder = dst_folder
      else
        # 親フォルダの情報取得
        parent_folder = doclibrary_folder_cnn.find_by_id(src_folder.parent_id)
        raise if parent_folder.blank? # エラーメッセージは上位メソッドで表示
      end

      # フォルダ情報変更
      src_folder.docs_last_updated_at = Time.now
      src_folder.level_no = parent_folder.level_no + 1
      src_folder.save!

      # 下位フォルダについて権限チェックと情報変更
      src_folder.children.each do |child_folder|
        update_move_folder(
            doclibrary_folder_cnn, child_folder.id, dst_folder_id, folder_level + 1)
      end
    rescue => ex
      raise ex.message
    end
  end

  # === コピーフォルダ作成メソッド
  #  本メソッドは、階層ごとにコピーフォルダを作成するメソッドである。
  # ==== 引数
  #  * src_folder_id: コピー対象フォルダID
  #  * dst_folder_id: コピー先フォルダID
  # ==== 戻り値
  #  なし
  def create_copy_folder(src_folder_id, dst_folder_id)
    doclibrary_folder_cnn = doclib_db_alias(Doclibrary::Folder)
    begin
      # コピー対象フォルダの取得
      src_folder = doclibrary_folder_cnn.find_by_id(src_folder_id)
      if src_folder.blank?
        raise I18n.t('rumi.doclibrary.drag_and_drop.message.src_copy_folder_not_found')
      end

      # コピー先フォルダの取得
      dst_folder = doclibrary_folder_cnn.find_by_id(dst_folder_id)
      if dst_folder.blank?
        raise I18n.t('rumi.doclibrary.drag_and_drop.message.dst_copy_folder_not_found')
      end

      # コピー対象フォルダの親フォルダへの管理権限があるかをチェック
      unless src_folder.parent_folder.admin_user?(Site.user.id)
        raise I18n.t('rumi.doclibrary.drag_and_drop.message.no_authority_to_edit_folder')
      end

      # コピー先フォルダへの管理権限があるかをチェック
      unless dst_folder.admin_user?(Site.user.id)
        raise I18n.t('rumi.doclibrary.drag_and_drop.message.no_authority_to_edit_folder')
      end

      new_folder = nil
      begin
        doclibrary_folder_cnn.transaction do
         # コピーフォルダを作成
          new_folder = doclibrary_folder_cnn.new
          new_folder.attributes = src_folder.attributes
          # 作成日、更新日リセット
          new_folder.created_at = nil
          new_folder.updated_at = nil
          new_folder.docs_last_updated_at = Time.now
          # フォルダ情報変更
          new_folder.parent_id = dst_folder.id
          new_folder.level_no  = dst_folder.level_no + 1
          new_folder.save!
        end
      rescue
        raise # エラーメッセージは上位メソッドで表示
      end

      # コピーフォルダにコピー元フォルダ内ののファイルをコピー
      src_folder.child_docs.each do |child_file|
        copy_file(child_file.id, new_folder.id, true);
      end

      # 下位フォルダをコピー
      src_folder.children.each do |child_folder|
        create_copy_folder(child_folder.id, new_folder.id)
      end
    rescue => ex
      raise ex.message
    ensure
      Doclibrary::Folder.remove_connection
    end
  end
end
