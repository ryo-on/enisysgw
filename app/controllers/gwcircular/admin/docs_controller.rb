# -*- encoding: utf-8 -*-
class Gwcircular::Admin::DocsController < Gw::Controller::Admin::Base

  include Gwboard::Controller::Scaffold
  include Gwboard::Controller::Common
  include Gwcircular::Model::DbnameAlias
  include Gwcircular::Controller::Authorize
  layout :select_layout
  require 'base64'
  require 'zlib'

  rescue_from ActionController::InvalidAuthenticityToken, :with => :invalidtoken

  def pre_dispatch
    params[:title_id] = 1
    @title = Gwcircular::Control.find_by_id(params[:title_id])
    return http_error(404) unless @title

    Page.title = "回覧板"
    @css = ["/_common/themes/gw/css/circular.css"]

    s_cond = ''
    s_cond = "?cond=#{params[:cond]}" unless params[:cond].blank?
    return redirect_to("#{gwcircular_menus_path}#{s_cond}") if params[:reset]
    
    params[:limit] = @title.default_limit unless @title.default_limit.blank?
    unless params[:id].blank? or params[:rid].present?
      item = Gwcircular::Doc.find(params[:id])
      unless item.blank?
        if item.doc_type == 0
          params[:cond] = 'owner'
        end
        if item.doc_type == 1
          params[:cond] = 'unread' if item.state == 'unread'
          params[:cond] = 'already' if item.state == 'already'
        end
      end
    end
  end

  def index
    redirect_to "#{@title.item_home_path}"
  end

  def show
    get_role_index
    return authentication_error(403) unless @is_readable

    admin_flags(@title.id)

    item = Gwcircular::Doc.new
    item.and :id, params[:id]
    item.and :state ,'!=', 'preparation'
    @item = item.find(:first)
    return http_error(404) if @item.blank?

    get_role_show(@item)  #admin, readable, editable
    @is_readable = false unless @item.target_user_code == Site.user.code unless @is_admin
    return authentication_error(403) unless @is_readable

    if @item.state == 'unread'
      @item.state = 'already'
      @item.published_at = Time.now
      @item.latest_updated_at = Time.now
      update_creater_editor_circular
      @item._commission_count = true
      @item.save
      params[:cond] = 'already'
    end unless @item.confirmation == 1

    @parent = Gwcircular::Doc.find_by_id(@item.parent_id)
    return http_error(404) unless @parent

    # 添付ファイルの取得
    @files = Gwcircular::File.where(:parent_id => @parent.id)

    commission_index
  end

  def gwbbs_forward
    item = Gwcircular::Doc.new
    item.and :id, params[:id]
    item.and :state ,'!=', 'preparation'
    @item = item.find(:first)
    return http_error(404) if @item.blank?

    @parent = Gwcircular::Doc.find_by_id(@item.parent_id)
    return http_error(404) unless @parent

    @forward_form_url = "/gwbbs/forward_select"
    @target_name = "gwbbs_form_select"
    forward_setting
  end

  def mail_forward
    item = Gwcircular::Doc.new
    item.and :id, params[:id]
    item.and :state ,'!=', 'preparation'
    @item = item.find(:first)
    return http_error(404) if @item.blank?

    @parent = Gwcircular::Doc.find_by_id(@item.parent_id)
    return http_error(404) unless @parent

    _url = Enisys::Config.application["webmail.root_url"]
    @forward_form_url = URI.join(_url, "/_admin/gw/webmail/INBOX/mails/gw_forward").to_s
    @target_name = "mail_form"

    forward_setting
  end

  def forward_setting
    #機能間転送の為の処理
    #本文の処理
    if @parent.body.include?("<")
      @gwcircular_text_body = "-------- Original Message --------<br />"
      #本文_タイトル
      @gwcircular_text_body << "タイトル： " + @parent.title + "<br />"
      #本文_作成日時
      @gwcircular_text_body << "作成日時： " + @parent.created_at.strftime('%Y-%m-%d %H:%M') + "<br />"
      #本文_作成者
      @gwcircular_text_body << "作成者： " + @parent.createrdivision + " " + @parent.creater + "<br />"
      #本文_回覧記事本文
      @gwcircular_text_body << @parent.body
    else
      @gwcircular_text_body = "-------- Original Message --------\r\n"
      #本文_タイトル
      @gwcircular_text_body << "タイトル： " + @parent.title + "\r\n"
      #本文_作成日時
      @gwcircular_text_body << "作成日時： " + @parent.created_at.strftime('%Y-%m-%d %H:%M') + "\r\n"
      #本文_作成者
      @gwcircular_text_body << "作成者： " + @parent.createrdivision + " " + @parent.creater + "\r\n"
      #本文_回覧記事本文
      @gwcircular_text_body << @parent.body
    end
    @gwcircular_text_body = Base64.encode64(@gwcircular_text_body).split().join()

    @tmp = ""
    @name = ""
    @content_type = ""
    @size = ""

    forword = Gwcircular::Doc.find_by_id(@parent.id)
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

  def commission_index(no_paginate=nil)
    item = Gwcircular::Doc.new
    item.and :title_id , @title.id
    item.and :doc_type , 1
    item.and :state ,'!=', 'preparation'
    item.and :parent_id, @item.parent_id
    item.and :target_user_code,'!=', Site.user.code
    item.search(params)
    item.page(params[:page], params[:limit]) if no_paginate.blank?
    @commissions = item.find(:all)
  end

  def edit
    get_role_new
    return authentication_error(403) unless @is_writable

    item = Gwcircular::Doc.new
    item.and :id, params[:id]
    item.and :state ,'!=', 'preparation'
    @item = item.find(:first)
    return http_error(404) unless @item
    get_role_edit(@item)

    @is_readable = false unless @item.target_user_code == Site.user.code unless @is_admin
    return authentication_error(403) unless @is_editable
    @parent = Gwcircular::Doc.find_by_id(@item.parent_id)
    return http_error(404) unless @parent
    Page.title = @title.title
  end

  def edit_show
    get_role_new
    return authentication_error(403) unless @is_writable

    item = Gwcircular::Doc.new
    item.and :id, params[:id]
    item.and :state ,'!=', 'preparation'
    @item = item.find(:first)
    return http_error(404) unless @item
    get_role_edit(@item)

    @parent = Gwcircular::Doc.find_by_id(@item.parent_id)
    return http_error(404) unless @parent

    @is_read_show = false
    return http_error(404) if params[:rid].blank?
    @myitem = Gwcircular::Doc.where(title_id: 1, id: params[:rid]).first
    commissions = Gwcircular::Doc.where("state != ?", 'preparation').where(title_id: 1, parent_id: @parent.id)
    commissions.each do |commission|
      @is_read_show = true if commission.target_user_code == Site.user.code and commission.is_readable_edit_show?
    end
    @is_read_show = true if @is_admin or @parent.target_user_code == Site.user.code
    return authentication_error(403) unless @is_read_show

    Page.title = @title.title

    # 添付ファイルの取得
    @files = Gwcircular::File.where(:parent_id => @item.id)
  end

  def update
    get_role_new
    return authentication_error(403) unless @is_writable
    @item = Gwcircular::Doc.find_by_id(params[:id])
    return http_error(404) unless @item

    @parent = Gwcircular::Doc.find_by_id(@item.parent_id)

    @is_writable = false unless @item.target_user_code == Site.user.code unless @is_admin
    return authentication_error(403) unless @is_writable

    @before_state = @item.state
    @item.attributes = params[:item]

    if @before_state == 'unread'
      @item.published_at = Time.now
    end if @item.published_at.blank?

    @item.latest_updated_at = Time.now
    update_creater_editor_circular
    @item._commission_count = true
    location = "#{@item.show_path}?cond=#{params[:cond]}"
 
    _update(@item, :success_redirect_uri=>location)
  end

  def already_update
    get_role_new
    return authentication_error(403) unless @is_writable
    @item = Gwcircular::Doc.find_by_id(params[:id])
    return http_error(404) unless @item

    @is_writable = false unless @item.target_user_code == Site.user.code unless @is_admin
    return authentication_error(403) unless @is_writable
    @item.state = 'already'
    @item.latest_updated_at = Time.now
    @item.published_at = Time.now
    update_creater_editor_circular
    @item._commission_count = true
    @item.save

    # 新着情報を既読に変更
    @item.parent_doc.seen_remind(Site.user.id)

    location = "#{@item.show_path}?cond=already"
    redirect_to location
  end

  private
  def invalidtoken
    return http_error(404)
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
