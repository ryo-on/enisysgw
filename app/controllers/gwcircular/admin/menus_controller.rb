# encoding:utf-8
class Gwcircular::Admin::MenusController < Gw::Controller::Admin::Base
  include Gwboard::Controller::Scaffold
  include Gwboard::Controller::Common
  include Gwcircular::Model::DbnameAlias
  include Gwcircular::Controller::Authorize

  rescue_from ActionController::InvalidAuthenticityToken, :with => :invalidtoken

  layout "admin/template/gwcircular"

  def pre_dispatch
    params[:title_id] = 1
    @title = Gwcircular::Control.find_by_id(params[:title_id])
    return http_error(404) unless @title

    Page.title = "回覧板"
    s_cond = ''
    s_cond = "?cond=#{params[:cond]}" unless params[:cond].blank?
    return redirect_to("#{gwcircular_menus_path}#{s_cond}") if params[:reset]

    @css = ["/_common/themes/gw/css/circular.css"]

    params[:limit] = @title.default_limit unless @title.default_limit.blank?
    unless params[:id].blank?

      item = Gwcircular::Doc.find_by_id(params[:id])
      unless item.blank?

        if item.doc_type == 0
          params[:cond] = 'owner'
        end unless params[:cond] == 'void'
        if item.doc_type == 1
          params[:cond] = 'unread' if item.state == 'unread'
          params[:cond] = 'already' if item.state == 'already'
        end unless params[:cond] == 'void'
      end
    end unless params[:cond] == 'void' unless params[:cond] == 'admin'
    params[:cond] = 'unread' if params[:cond].blank?
  end

  def jgw_circular_path
    return gwcircular_menus_path
  end

  def index
    get_role_index
    return authentication_error(403) unless @is_readable
    case params[:cond]
    when 'unread'
      unread_index
    when 'already'
      already_read_index
    when 'owner'
      owner_index
    when 'void'
      owner_index
    when 'admin'
      return authentication_error(403) unless @is_admin
      admin_index
    else
      unread_index
    end

    #添付ファイルの検索を行う
    unless params[:kwd].blank?
      search_file_index
    end
    Page.title = @title.title
  end

  def show
    get_role_index
    return authentication_error(403) unless @is_readable

    item = Gwcircular::Doc.new
    item.and :id, params[:id]
    @item = item.find(:first)
    return http_error(404) unless @item

    get_role_show(@item)  #admin, readable, editable

    @is_readable = false unless @item.target_user_code == Site.user.code unless @is_admin
    return authentication_error(403) unless @is_readable

    # 添付ファイルの取得
    @files = Gwcircular::File.where(:parent_id => @item.id)

    commission_index
  end

  def new
    get_role_new
    return authentication_error(403) unless @is_writable

    default_published = is_integer(@title.default_published)
    default_published = 14 unless default_published

    title = ''
    body = ''
    _body = ''
    readers_json = []
    spec_config = 3
    importance = 1
    cnt = 0
    forword_flg = false
    copy_flg = false
    expiry_date = default_published.days.since.strftime("%Y-%m-%d %H:00")

    if params[:forword_id].present?
      forword_flg = true
      @forword_id = params[:forword_id]
    end
    if params[:copy_id].present?
      copy_flg = true
      @forword_id = params[:copy_id]
    end

    if params[:forword_id].present? || params[:copy_id].present?
      forword = Gwcircular::Doc.get_forword(@forword_id)

      return authentication_error(500) if forword.blank?

      forword.each do |f|
        title = "転送: " + f.title
        if f.parent_id.present?
          parent = Gwcircular::Doc.find_by_id(f.parent_id)
          _body = parent.body
          @forword_id = parent.id
        else
          _body = f.body
        end

        if forword_flg
          title = "転送: " + f.title
          body = "<p>-------- Original Message --------</p><p></p>" + _body
        end

        if copy_flg
          title = f.title
          body = _body
          users = System::User.without_disable
          if f.parent_id.present?
            if parent.reader_groups_json.present?
              group_infos = JsonParser.new.parse(parent.reader_groups_json)
              group_infos.each do |p|
                users.each do |u|
                  readers_json << p  if u.id.to_i == p[1].to_i
                end
              end
            end
            if parent.readers_json.present?
              user_infos = JsonParser.new.parse(parent.readers_json)
              user_infos.each do |p|
                users.each do |u|
                  if u.id.to_i == p[1].to_i
                    cnt = 0
                    readers_json.each do |r|
                      cnt = 1 if r[1].to_i == p[1].to_i
                    end
                    readers_json << p  if cnt == 0
                  end
                end
              end
            end
          else
            if f.reader_groups_json.present?
              group_infos = JsonParser.new.parse(f.reader_groups_json)
              group_infos.each do |f|
                users.each do |u|
                  readers_json << f  if u.id.to_i == f[1].to_i
                end
              end
            end
            if f.readers_json.present?
              user_infos = JsonParser.new.parse(f.readers_json)
              user_infos.each do |f|
                users.each do |u|
                  if u.id.to_i == f[1].to_i
                    cnt = 0
                    readers_json.each do |r|
                      cnt = 1 if r[1].to_i == f[1].to_i
                    end
                    readers_json << f  if cnt == 0
                  end
                end
              end
            end
          end
        end
        readers_json = readers_json.to_json
        unless f.expiry_date < Time.now
          expiry_date = f.expiry_date
        end
        importance = f.importance.to_i if f.importance.present?
        spec_config = f.spec_config.to_i if f.spec_config.present?

        if parent.blank?
          files = Gwcircular::File.find_by_parent_id(f.id)
        else
          files = Gwcircular::File.find_by_parent_id(parent.id)
        end
        if files.present?
          cnt = 1
        end
      end
    end

    @item = Gwcircular::Doc.create({
      :state => 'preparation',
      :title_id => @title.id,
      :latest_updated_at => Time.now,
      :doc_type => 0,
      :title => title,
      :body => body,
      :section_code => Site.user_group.code,
      :target_user_id => Site.user.id,
      :target_user_code => Site.user.code,
      :target_user_name => Site.user.name,
      :confirmation => 0,
      :spec_config => spec_config,
      :importance => importance,
      :able_date => Time.now.strftime("%Y-%m-%d %H:%M"),
      :expiry_date => expiry_date,
      :readers_json => readers_json
    })
    @item.state = 'draft'

    if cnt == 1
      forword = Gwcircular::Doc.find_by_id(@forword_id)
      copy_file = Gwcircular::Doc.new
      # 添付ファイル情報コピー
      forword.files.each do |attach|
        attributes = attach.attributes.reject do |key, value|
          key == 'id' || key == 'parent_id'
        end
        attach_file = copy_file.files.build(attributes)
        attach_file.created_at = Time.now
        attach_file.updated_at = Time.now

        # 添付ファイルの存在チェック
        unless File.exist?(attach.f_name)
          raise I18n.t('rumi.doclibrary.drag_and_drop.message.attached_file_not_found')
        end
        upload = ActionDispatch::Http::UploadedFile.new({
          :filename => attach.filename,
          :content_type => attach.content_type,
          :size => attach.size,
          :memo => attach.memo,
          :title_id => attach.title_id,
          :parent_id => attach.parent_id,
          :content_id => @title.upload_system,
          :db_file_id => 0,
          :tempfile => File.open(attach.f_name)
        })
        attach_file._upload_file(upload)
        attach_file.parent_id = @item.id
        attach_file.save
      end
    end

  end

  def edit
    get_role_new
    return authentication_error(403) unless @is_writable

    item = Gwcircular::Doc.new
    item.and :id, params[:id]
    @item = item.find(:first)
    return http_error(404) unless @item
    get_role_edit(@item)
    return authentication_error(403) unless @is_editable

    Page.title = @title.title
  end

  def update
    get_role_new
    return authentication_error(403) unless @is_writable
    @item = Gwcircular::Doc.find(params[:id])

    @before_state = @item.state
    @item.attributes = params[:item]

    @item.state = params[:item][:state]

    time_now = Time.now
    @item.latest_updated_at = time_now

    if @item.target_user_code.blank?
      @item.target_user_code = Site.user.code
      @item.target_user_name = Site.user.name
    end if @is_admin

    unless @is_admin
      @item.target_user_code = Site.user.code
      @item.target_user_name = Site.user.name
    end
    update_creater_editor_circular
    @item._commission_count = true
    @item._commission_state = @before_state
    @item._commission_limit = @title.commission_limit

    if @before_state == 'preparation'
      @item.created_at = time_now
    end

    s_cond = '?cond=owner'
    s_cond = '?cond=admin' if params[:cond] == 'admin'
    if @item.state == 'draft'
      location = "#{jgw_circular_path}#{s_cond}"
    else
      location = "#{jgw_circular_path}/#{@item.id}/circular_publish#{s_cond}"
    end
    _update(@item, :success_redirect_uri=>location)
  end

  def destroy
    @item = Gwcircular::Doc.find(params[:id])
    get_role_edit(@item)
    return authentication_error(403) unless @is_editable
    s_cond = '?cond=owner'
    s_cond = '?cond=admin' if params[:cond] == 'admin'
    _destroy_plus_location(@item, "#{@title.menus_path}#{s_cond}" )
  end

  def unread_index(no_paginate=nil)
    item = Gwcircular::Doc.new
    item.and :title_id , @title.id
    item.and :doc_type , 1
    item.and :state , 'unread'
    item.and :target_user_code , Site.user.code
    item.and "sql", gwcircular_select_status(params)
    item.search_creator(params)
    if params[:kwd].present?
      item.and "sql", search_kwd_cond_parents
    end
    item.search_date(params)
    item.order circular_order
    item.page(params[:page], params[:limit]) if no_paginate.blank?
    @items = item.find(:all)
    @groups = Gwcircular::Doc.unread_info(@title.id).select_createrdivision_info
    @monthlies = Gwcircular::Doc.unread_info(@title.id).select_monthly_info
  end

  def already_read_index(no_paginate=nil)
    item = Gwcircular::Doc.new
    item.and :title_id , @title.id
    item.and :doc_type , 1
    item.and :state , 'already'
    item.and :target_user_code , Site.user.code
    item.and "sql", gwcircular_select_status(params)
    item.search_creator(params)
    if params[:kwd].present?
      item.and "sql", search_kwd_cond_parents
    end
    item.search_date(params)
    item.order circular_order
    item.page(params[:page], params[:limit]) if no_paginate.blank?
    @items = item.find(:all)
    @groups = Gwcircular::Doc.already_info(@title.id).select_createrdivision_info
    @monthlies = Gwcircular::Doc.already_info(@title.id).select_monthly_info
  end

  def owner_index(no_paginate=nil)
    item = Gwcircular::Doc.new
    item.and :title_id , @title.id
    item.and :doc_type , 0
    item.and :state ,'!=', 'preparation'
    item.and :target_user_code, Site.user.code
    item.and "sql", gwcircular_select_status(params)
    item.order circular_order
    item.search(params)
    item.search_creator(params)
    item.page(params[:page], params[:limit]) if no_paginate.blank?
    @items = item.find(:all)
    @groups = Gwcircular::Doc.owner_info(@title.id).select_createrdivision_info
    @monthlies = Gwcircular::Doc.owner_info(@title.id).select_monthly_info
  end

  def commission_index(no_paginate=nil)
    item = Gwcircular::Doc.new
    item.and :title_id , @title.id
    item.and :doc_type , 1
    item.and :state ,'!=', 'preparation'
    item.and :parent_id, @item.id
    item.and "sql", gwcircular_select_status(params)
    item.search(params)
    item.search_creator(params)
    item.order "state DESC, id"
    item.page(params[:page], params[:limit]) if no_paginate.blank?
    @commissions = item.find(:all)
  end

  def admin_index(no_paginate=nil)
    item = Gwcircular::Doc.new
    item.and :title_id , @title.id
    item.and :doc_type , 0
    item.and :state ,'!=', 'preparation'
    item.and "sql", gwcircular_select_status(params)
    item.order circular_order
    item.search(params)
    item.search_creator(params)
    item.page(params[:page], params[:limit]) if no_paginate.blank?
    @items = item.find(:all)
    @groups = Gwcircular::Doc.admin_info(@title.id).select_createrdivision_info
    @monthlies = Gwcircular::Doc.admin_info(@title.id).select_monthly_info
  end

  def sql_where
    sql = Condition.new
    sql.and :parent_id, @item.id
    sql.and :title_id, @item.title_id
    return sql.where
  end

  def clone
    item = Gwcircular::Doc.new
    item.and :id, params[:id]
    @item = item.find(:first)
    return http_error(404) unless @item
    get_role_edit(@item)
    clone_doc(@item)
  end

  def circular_publish
    item = Gwcircular::Doc.find_by_id(params[:id])
    return http_error(404) unless item
    item.publish_delivery_data(params[:id])
    item.state = 'public'
    item.save
    s_cond = '?cond=owner'
    s_cond = '?cond=admin' if params[:cond] == 'admin'
    redirect_to "#{@title.menus_path}#{s_cond}"
  end

  private
  def invalidtoken
    return http_error(404)
  end

  def search_file_index
    file = Gwcircular::File.new
    file.and 'gwcircular_docs.title_id' , @title.id
    file.and "sql", gwcircular_select_status(params)
    file.search(params)

    parentids = Array.new
    case params[:cond]
    when 'unread'
      condition = "state='unread' AND doc_type=1 AND target_user_code='#{Site.user.code}'"
      file.order 'gwcircular_docs.expiry_date DESC, gwcircular_docs.id DESC, gwcircular_files.filename'
    when 'already'
      condition = "state='already' AND doc_type=1 AND target_user_code='#{Site.user.code}'"
      file.order 'gwcircular_docs.expiry_date DESC, gwcircular_docs.id DESC, gwcircular_files.filename'
    when 'owner', 'void'
      condition = "state!='preparation' AND doc_type=0 AND target_user_code='#{Site.user.code}'"
      file.order 'gwcircular_docs.id DESC, gwcircular_files.filename'
      file.and "sql", "gwcircular_docs.state!='preparation' AND gwcircular_docs.doc_type=0 AND gwcircular_docs.target_user_code='#{Site.user.code}'"
    when 'admin'
      condition = "state!='preparation' AND doc_type=0"
      file.order 'gwcircular_docs.id DESC, gwcircular_files.filename'
      file.and "sql", "gwcircular_docs.state!='preparation' AND gwcircular_docs.doc_type=0"
    else
      condition = "state='unread' AND doc_type=1 AND target_user_code='#{Site.user.code}'"
      file.order 'gwcircular_docs.expiry_date DESC, gwcircular_docs.id DESC, gwcircular_files.filename'
    end

    items = Gwcircular::Doc.find(:all, :conditions=>condition)
    items.each do |item|
      parent = Gwcircular::Doc.find_by_id(item.parent_id)
      parentids << parent.id unless parent.blank?
    end
    if parentids.present?
      search_parent_ids = Gw.join([parentids], ',')
      file.and "sql", "gwcircular_docs.id IN (#{search_parent_ids})"
    elsif parentids.blank? && (params[:cond] == 'unread' || params[:cond] == 'already')
      return @files
    end
    file.page(params[:page], params[:limit])
    file.join "INNER JOIN gwcircular_docs ON gwcircular_files.parent_id = gwcircular_docs.id"
    @files = file.find(:all)
  end

  def search_kwd_cond_parents
    parent = Gwcircular::Doc.new
    parent.and :title_id , @title.id
    parent.and :doc_type , 0
    parent.and :state ,'!=', 'preparation'
    parent.and "sql", gwcircular_select_status(params)
    parent.order 'id DESC'
    parent.search_kwd(params)
    parents = parent.find(:all, :select => "id")

    cond = "parent_id IN ('')"
    parentids = Array.new
    parents.each do |parent|
      parentids << parent.id unless parent.blank?
    end
    if parentids.present?
      search_parent_ids = Gw.join([parentids], ',')
      cond = "parent_id IN (#{search_parent_ids})"
    end
    return cond
  end

  def circular_order
    case params[:cond]
    when 'unread','already'
      if params[:sort_key].present? && params[:category] == 'DATE'
        item_order = "#{params[:sort_key]} #{params[:order]}, created_at #{params[:order]}"
      elsif params[:sort_key].present? && params[:category] == 'GROUP'
        item_order = "#{params[:sort_key]} #{params[:order]}, createrdivision_id #{params[:order]}, id #{params[:order]}"
      elsif params[:sort_key].present?
        item_order = "#{params[:sort_key]} #{params[:order]}, id #{params[:order]}"
      elsif params[:category] == 'DATE'
        item_order = "created_at DESC"
      elsif params[:category] == 'GROUP'
        item_order = "createrdivision_id ASC, expiry_date DESC, id DESC"
      else
        item_order = "expiry_date DESC, id DESC"
      end
    when 'owner','admin'
      if params[:sort_key].present? && params[:category] == 'DATE'
        item_order = "#{params[:sort_key]} #{params[:order]}, created_at #{params[:order]}"
      elsif params[:sort_key].present? && params[:category] == 'GROUP'
        item_order = "#{params[:sort_key]} #{params[:order]}, createrdivision_id #{params[:order]}, id #{params[:order]}"
      elsif params[:sort_key].present?
        item_order = "#{params[:sort_key]} #{params[:order]}, id #{params[:order]}"
      elsif params[:category] == 'DATE'
        item_order = "created_at DESC"
      elsif params[:category] == 'GROUP'
        item_order = "createrdivision_id ASC, id DESC"
      elsif params[:category] == 'EXPIRY'
        item_order = "expiry_date DESC, id DESC"
      else
        item_order = "id DESC"
      end
    else
      if params[:sort_key].present? && params[:category] == 'DATE'
        item_order = "#{params[:sort_key]} #{params[:order]}, created_at #{params[:order]}"
      elsif params[:sort_key].present? && params[:category] == 'GROUP'
        item_order = "#{params[:sort_key]} #{params[:order]}, createrdivision_id #{params[:order]}, id #{params[:order]}"
      elsif params[:sort_key].present?
        item_order = "#{params[:sort_key]} #{params[:order]}, id #{params[:order]}"
      elsif params[:category] == 'DATE'
        item_order = "created_at DESC"
      elsif params[:category] == 'GROUP'
        item_order = "createrdivision_id ASC, expiry_date DESC, id DESC"
      else
        item_order = "expiry_date DESC, id DESC"
      end
    end
    return item_order
  end
end
