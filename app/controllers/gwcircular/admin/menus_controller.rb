# encoding:utf-8
class Gwcircular::Admin::MenusController < Gw::Controller::Admin::Base
  include Gwboard::Controller::Scaffold
  include Gwboard::Controller::Common
  include Gwcircular::Model::DbnameAlias
  include Gwcircular::Controller::Authorize
  require 'base64'
  require 'zlib'

  rescue_from ActionController::InvalidAuthenticityToken, :with => :invalidtoken

  protect_from_forgery :except => [:forward]

  layout :select_layout

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

  def gwbbs_forward
    item = Gwcircular::Doc.new
    item.and :id, params[:id]
    @item = item.find(:first)
    return http_error(404) unless @item

    @forward_form_url = "/gwbbs/forward_select"
    @target_name = "gwbbs_form_select"
    forward_setting
  end

  def mail_forward
    item = Gwcircular::Doc.new
    item.and :id, params[:id]
    @item = item.find(:first)
    return http_error(404) unless @item

    _url = Enisys::Config.application["webmail.root_url"]
    @forward_form_url = URI.join(_url, "/_admin/gw/webmail/INBOX/mails/gw_forward").to_s
    @target_name = "mail_form"

    forward_setting
  end

  def forward_setting
    #機能間転送の為の処理
    #本文の処理
    if @item.body.include?("<")
      @gwcircular_text_body = "-------- Original Message --------<br />"
      #本文_タイトル
      @gwcircular_text_body << "タイトル： " + @item.title + "<br />"
      #本文_作成日時
      @gwcircular_text_body << "作成日時： " + @item.created_at.strftime('%Y-%m-%d %H:%M') + "<br />"
      #本文_作成者
      @gwcircular_text_body << "作成者： " + @item.createrdivision + " " + @item.creater + "<br />"
      #本文_回覧記事本文
      @gwcircular_text_body << @item.body
    else
      @gwcircular_text_body = "-------- Original Message --------\r\n"
      #本文_タイトル
      @gwcircular_text_body << "タイトル： " + @item.title + "\r\n"
      #本文_作成日時
      @gwcircular_text_body << "作成日時： " + @item.created_at.strftime('%Y-%m-%d %H:%M') + "\r\n"
      #本文_作成者
      @gwcircular_text_body << "作成者： " + @item.createrdivision + " " + @item.creater + "\r\n"
      #本文_回覧記事本文
      @gwcircular_text_body << @item.body
    end
    @gwcircular_text_body = Base64.encode64(@gwcircular_text_body).split().join()

    @tmp = ""
    @name = ""
    @content_type = ""
    @size = ""
    forword = Gwcircular::Doc.find_by_id(@item.id)
    forword.files.each do |attach|
      f = File.open(attach.f_name)
      @tmp.concat "," if @tmp.present?
      tmp = Zlib::Deflate.deflate(f.read, Zlib::BEST_COMPRESSION)
      @tmp.concat Base64.encode64(tmp).split().join()
      @name.concat "," if @name.present?
      @name.concat attach.filename.to_s
      @content_type.concat "," if @content_type.present?
      @content_type.concat attach.content_type.to_s
      @size.concat "," if @size.present?
      @size.concat attach.size.to_s
    end
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

  def forward
    params[:authenticity_token] = form_authenticity_token
    get_role_new
    return authentication_error(403) unless @is_writable
    default_published = is_integer(@title.default_published)
    default_published = 14 unless default_published
    title = ''
    body = ''
    readers_json = []
    spec_config = 3
    importance = 1
    expiry_date = default_published.days.since.strftime("%Y-%m-%d %H:00")

    #件名が存在すれば回覧板のタイトルに挿入
    title = params[:title] if params[:title].present?

    #本文が存在すれば回覧板の本文に挿入
    __body = Base64.decode64(params[:body]).to_s if params[:body].present?
    if params[:body].present? && __body.include?("<")
      body = __body.force_encoding("utf-8")
    else
      _body = __body.split("\r\n");
      _body.each do |b|
        body << b.force_encoding("utf-8") + "<br />"
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

    #添付ファイルが存在すれば添付ファイルのコピーを行う
    if params[:tmp].present?
      forward = params[:tmp].split(",")
      name = params[:name].split(",")
      content_type = params[:content_type].split(",")
      size = params[:size].split(",")
      # 添付ファイル情報コピー
      cnt = 0
      forward.each do |attach|
        if content_type[cnt].index("image").blank?
          @max_size = is_integer(@title.upload_document_file_size_max)
        else
          @max_size = is_integer(@title.upload_graphic_file_size_max)
        end
        @max_size = 5 if @max_size.blank?
        if @max_size.megabytes < size[cnt].to_i
          if size[cnt] != 0
            mb = size[cnt].to_f / 1.megabyte.to_f
            mb = (mb * 100).to_i
            mb = sprintf('%g', mb.to_f / 100)
          end
          flash[:notice] = "ファイルサイズが制限を超えているため、ファイルが添付できませんでした。【最大#{@max_size}MBの設定です。】【#{mb}MBのファイルを登録しようとしています。】"
        elsif name[cnt].bytesize > Enisys.config.application['sys.max_file_name_length']
          flash[:notice] = I18n.t('rumi.attachment.message.name_too_long')
        else
          begin
            filename = "attach_" + cnt.to_s
            tmpfile = Tempfile.new(filename)

            t_file = File.open(tmpfile.path,"w+b")
            at = Base64.decode64(attach)
            t_file.write(Zlib::Inflate.inflate(at))
            t_file.close
            upload = ActionDispatch::Http::UploadedFile.new({
              :filename => name[cnt],
              :content_type => content_type[cnt],
              :size => size[cnt],
              :memo => '',
              :title_id => 1,
              :parent_id => @item.id,
              :content_id => @title.upload_system,
              :db_file_id => 0,
              :tempfile => File.open(t_file.path)
            })

            tmpfile = Gwcircular::File.new({
              :content_type => content_type[cnt],
              :filename => name[cnt],
              :size => size[cnt],
              :memo => '',
              :title_id => 1,
              :parent_id => @item.id,
              :content_id => @title.upload_system,
              :db_file_id => 0
            })
            tmpfile._upload_file(upload)
            tmpfile.save
          rescue => ex
            if ex.message=~/File name too long/
              flash[:notice] = 'ファイル名が長すぎるため保存できませんでした。'
            else
              flash[:notice] = ex.message
            end
          end
        end
        cnt = cnt + 1
      end
    end

    render action: :new, layout: "admin/template/mail_forward"
  end

  def close
    get_role_new
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
    s_cond << '&request_path=' + params[:request_path] if params[:request_path].present?
    if @item.state == 'draft'
      if params[:request_path].present?
        location = "#{jgw_circular_path}/close"
      else
        location = "#{jgw_circular_path}#{s_cond}"
      end
    else
      location = "#{jgw_circular_path}/#{@item.id}/circular_publish#{s_cond}"
    end
    _update(@item, :success_redirect_uri=>location) if params[:request_path].blank?
    _update(@item, :success_redirect_uri=>location,:request_path=>params[:request_path]) if params[:request_path].present?
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
    if params[:request_path].present?
      redirect_to "#{jgw_circular_path}/close"
    else
      redirect_to "#{@title.menus_path}#{s_cond}"
    end
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
        item_order = "created_at DESC, id DESC"
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
        item_order = "created_at DESC, id DESC"
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
        item_order = "created_at DESC, id DESC"
      end
    end
    return item_order
  end

protected

  def select_layout
    layout = "admin/template/gwcircular"
    case params[:action].to_sym
    when :gwbbs_forward, :mail_forward
      layout = "admin/template/forward_form"
    end
    layout
  end
end
