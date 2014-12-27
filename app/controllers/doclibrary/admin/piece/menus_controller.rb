class Doclibrary::Admin::Piece::MenusController < Gw::Controller::Admin::Base
  include Gwboard::Controller::Scaffold
  include Gwboard::Controller::Common
  include Doclibrary::Model::DbnameAlias
  include Doclibrary::Controller::AdmsInclude
  include Rumi::Doclibrary::Authorize

  def initialize_scaffold
    skip_layout
    @title = Doclibrary::Control.find_by_id(params[:title_id])
    return error_gwbbs_no_title if @title.blank?

    params[:state] = @title.default_folder.to_s if params[:state].blank?
    unless params[:state] == 'GROUP'
      folder = doclib_db_alias(Doclibrary::Folder)
      @folder_items = folder.find(:all, :order=>"level_no DESC, sort_no DESC, id DESC")
    else
      @grp_items = Gwboard::Group.level3_all
    end
    Doclibrary::Folder.remove_connection
  end

  def index
    get_role_index
#    return http_error(404) unless @is_readable

    if params[:state] == 'GROUP'
      make_hash_variable_doc_counts2
    else
      index_category
    end
  end

  def index_category
    return false if params[:state] == 'GROUP'

    folder = doclib_db_alias(Doclibrary::ViewAclFolder)
    @items = folder.find(:all, :conditions=>["parent_id IS NULL"], :order=>"level_no, sort_no, id")
    fid = params[:cat]
    set_folder_array(fid)
    Doclibrary::Folder.remove_connection
    Doclibrary::GroupFolder.remove_connection
    Doclibrary::ViewAclFolder.remove_connection
  end

  def set_folder_array(param)
    @folders = []
    return if param.blank?
    fid = param.to_s
    @folder_items.each do |item|
      if fid.to_s == item.id.to_s
        @folders[item.level_no] = item.id
        fid = item.parent_id.to_s
      end if item.state == 'public'
    end
  end
  
  def make_hash_variable_doc_counts

    #改善版を呼び出してリターン
    if TRUE
      make_hash_variable_doc_counts2
      return
    end
    
    p_grp_code = ''
    p_grp_code = Site.user_group.parent.code unless Site.user_group.parent.blank?
    grp_code = ''
    grp_code = Site.user_group.code unless Site.user_group.blank?

    str_where  = " (state = 'public' AND title_id = #{@title.id} AND acl_flag = 0)"
    if @is_admin

      str_where  += " OR (state = 'public' AND title_id = #{@title.id} AND acl_flag = 9)"
    else
      str_where  += " OR (state = 'public' AND title_id = #{@title.id} AND acl_flag = 1 AND acl_section_code = '#{p_grp_code}')"
      str_where  += " OR (state = 'public' AND title_id = #{@title.id} AND acl_flag = 1 AND acl_section_code = '#{grp_code}')"
      str_where  += " OR (state = 'public' AND title_id = #{@title.id} AND acl_flag = 2 AND acl_user_code = '#{Site.user.code}')"
    end
    str_sql  = 'SELECT doclibrary_view_acl_doc_counts.section_code, SUM(doclibrary_view_acl_doc_counts.cnt) AS total_cnt'
    str_sql += ' FROM doclibrary_view_acl_doc_counts'
    str_sql += ' WHERE ' + str_where
    str_sql += ' GROUP BY doclibrary_view_acl_doc_counts.section_code'
    item = doclib_db_alias(Doclibrary::ViewAclDocCount)
    @group_doc_counts = item.find_by_sql(str_sql).index_by(&:section_code)
  end

  def make_hash_variable_doc_counts2
    user_group_parent_ids = Site.user.user_group_parent_ids.join(",")
    is_admin = @is_admin.blank? ? FALSE : TRUE

    str_where  = " (state = 'public' AND doclibrary_folders.title_id = #{@title.id}) AND ((acl_flag = 0)"
    if is_admin
      str_where  += " OR (acl_flag = 9))"
    elsif user_group_parent_ids.present?
      str_where  += " OR (acl_flag = 1 AND acl_section_id IN (#{user_group_parent_ids}))"
      str_where  += " OR (acl_flag = 2 AND acl_user_id = '#{Site.user.id}'))"
    else
      str_where  += ")"
    end

    str_sql = 'SELECT doclibrary_folders.id FROM doclibrary_folder_acls, doclibrary_folders'
    str_sql += ' WHERE doclibrary_folder_acls.folder_id = doclibrary_folders.id'
    str_sql += ' AND ( ' + str_where + ' )'
    str_sql += ' GROUP BY doclibrary_folders.id'

    cnn_view_acl_folders = doclib_db_alias(Doclibrary::ViewAclFolder)
    view_acl_folders = cnn_view_acl_folders.find_by_sql(str_sql)
    folder_ids = view_acl_folders.map{|f| f.id}.join(",")
    cnn_view_acl_folders.remove_connection

    @group_doc_counts = []
    unless folder_ids.blank?
      str_sql = "SELECT section_code, COUNT(id) AS total_cnt FROM doclibrary_docs"
      str_sql += " WHERE category1_id IN (#{folder_ids}) AND state = 'public'"
      str_sql += " GROUP BY section_code"

      cnn_docs = doclib_db_alias(Doclibrary::Doc)
      docs = cnn_docs.find_by_sql(str_sql)
      cnn_docs.remove_connection
      @group_doc_counts = docs.index_by(&:section_code)
    end
  end

  # === 索引ツリー更新メソッド
  #  本メソッドは、索引ツリーのフォルダ「＋」「ー」ボタンクリック時に索引ツリーを更新するメソッドである。
  # ==== 引数
  #  なし
  # ==== 戻り値
  #  なし
  def refresh_folder_trees
    # フォルダ表示に必要な各種変数を準備
    initialize_scaffold
    index

    # 現在展開表示中のフォルダIDを取得
    open_folders = []
    unless params[:open_folders].blank?
      open_folders = params[:open_folders].split(',').map{|id| id.to_i} 
    end

    # 展開表示中のフォルダID配列を変更
    unless params[:folder_open_state].blank?
      if params[:folder_open_state] == 'close'
        # 「＋」ボタンクリック時
        open_folders << params[:folder_id].to_i unless params[:folder_id].blank?
      elsif params[:folder_open_state] == 'open'
        # 「ー」ボタンクリック時
        cnn = doclib_db_alias(Doclibrary::Folder)
        folder = cnn.find(params[:folder_id])
        cnn.remove_connection

        unless folder.blank?
          # 指定フォルダと配下フォルダ全て展開表示をやめる
          child_folder_ids = [folder.id]
          child_folder_ids = folder.get_child_folder_ids(child_folder_ids)
          open_folders.delete_if{|id| child_folder_ids.include?(id)}
        end
      end
      open_folders.uniq!
    end
    params[:open_folders] = open_folders.join(',')

    respond_to do |format|
      format.js {render :layout => false }
    end
  end
end
