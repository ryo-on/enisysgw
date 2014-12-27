#encoding:utf-8

module Gwcircular::GwcircularHelper
  def system_name
    return 'gwcircular'
  end

  def item_home_path
    return "/#{system_name}/"
  end

  def file_base_path
    return "/_attaches/#{system_name}"
  end
  
  def current_path
    return gwcircular_menus_path
  end

 	def public_uri(item)
    name = item.name
    content.public_uri + name + '/'
  end

  def public_path(item)
    name = item.name
    if name =~ /^[0-9]{8}$/
      _name = name
    else
      _name = File.join(name[0..0], name[0..1], name[0..2], name)
    end
    Site.public_path + content.public_uri + _name + '/index.html'
  end

  def item_path(item)
    return current_path
  end

  def show_path(item)
    if item.doc_type == 0
      return "#{current_path}/#{item.id}"
    else
      return "#{item_home_path}docs/#{item.id}"
    end
  end

  def csv_exports_path(item, condition)
    if item.doc_type == 0
      return "#{item_home_path}#{item.id}/csv_exports?cond=#{condition}"
    else
      return '#'
    end
  end
  
  def file_exports_path(item, condition)
    if item.doc_type == 0
      return "#{item_home_path}#{item.id}/file_exports?cond=#{condition}"
    else
      return '#'
    end
  end

  def edit_path(item)
    return "#{item_home_path}#{item.id}/edit"
  end

  def doc_edit_path(item)
    return "#{item_home_path}docs/#{item.id}/edit"
  end
  
  def doc_edit_show_path(item)
    return "#{item_home_path}docs/#{item.id}/edit_show"
  end

  def doc_state_already_update(item)
    return "#{item_home_path}docs/#{item.id}/already_update"
  end

  def clone_path(item)
    return "#{current_path}/#{item.id}/clone"
  end

  def delete_path(item)
    return "#{current_path}/#{item.id}"
  end

  def update_path(item)
    return "#{current_path}/#{item.id}"
  end

  def csv_export_file_path(item)
    if item.doc_type == 0
      return "#{current_path}/#{item.id}/csv_exports/export_csv"
    else
      return '#'
    end
  end

  def file_export_path(item)
    if item.doc_type == 0
      return "#{current_path}/#{item.id}/file_exports"
    else
      return '#'
    end
  end

  def status_name(item)
    str = ''
    if item.doc_type == 0
      str = '下書き' if item.state == 'draft'
      str = '配信済み' if item.state == 'public'
      str = '期限終了' if item.expiry_date < Time.now unless item.expiry_date.blank? if item.state == 'public'
    end
    if item.doc_type == 1
      str = '非通知' if item.state == 'preparation'
      str = '配信予定' if item.state == 'draft'
      str = '<div align="center"><span class="required">未読</span></div>' if item.state == 'unread'
      str = '<div align="center"><span class="notice">既読</span></div>' if item.state == 'already'
      str = '期限切れ' if item.expiry_date < Time.now unless item.expiry_date.blank? if item.state == 'public'
    end

    return str
  end
  
  def status_name_show(item)
    str = ''
    if item.doc_type == 0
      str = '下書き' if item.state == 'draft'
      str = '配信済み' if item.state == 'public'
      str = '期限終了' if item.expiry_date < Time.now unless item.expiry_date.blank? if item.state == 'public'
    end
    if item.doc_type == 1
      str = '非通知' if item.state == 'preparation'
      str = '配信予定' if item.state == 'draft'
      str = '<span class="required">未読</span>' if item.state == 'unread'
      str = '<span class="notice">既読</span>' if item.state == 'already'
      str = '期限切れ' if item.expiry_date < Time.now unless item.expiry_date.blank? if item.state == 'public'
    end

    return str
  end

  def ret_str_search_title_lbl
    str = ''
    # 検索結果の文言、デザイン変更
    unless params[:kwd].blank? and params[:creator].blank? and params[:expirydate_start].blank? and
          params[:expirydate_end].blank? and params[:createdate_start].blank? and params[:createdate_end].blank?
      str = '<h4 class="rumi-search-title">検索結果</h4>'
    end
    return str
  end

  def file_show_path(item, params)
    case params[:cond]
    when 'unread'
      condition = "state='unread' AND doc_type=1 AND target_user_code='#{Site.user.code}' AND parent_id='#{item.id}'"
      item = Gwcircular::Doc.find(:first, :conditions=>condition)
    when 'already'
      condition = "state='already' AND doc_type=1 AND target_user_code='#{Site.user.code}' AND parent_id='#{item.id}'"
      item = Gwcircular::Doc.find(:first, :conditions=>condition)
    end

    if item.doc_type == 0
      return "#{current_path}/#{item.id}"
    else
      return "#{item_home_path}docs/#{item.id}"
    end
  end

  def cond_param(param, number=1)
    s_cond = ''
    if number == 1
      s_cond = '?cond=unread' if param == 'unread'
      s_cond = '?cond=already' if param == 'already'
      s_cond = '?cond=owner' if param == 'owner'
      s_cond = '?cond=admin' if param == 'admin'
    else
      s_cond = '&cond=unread' if param == 'unread'
      s_cond = '&cond=already' if param == 'already'
      s_cond = '&cond=owner' if param == 'owner'
      s_cond = '&cond=admin' if param == 'admin'
    end
    return s_cond
  end

  def take_params(sort_key=nil, order=nil)
    params_hash = {}
    params_hash[:kwd] = params[:kwd] unless params[:kwd].blank?
    params_hash[:creator] = params[:creator] unless params[:creator].blank?
    params_hash[:expirydate_start] = params[:expirydate_start] unless params[:expirydate_start].blank?
    params_hash[:expirydate_end] = params[:expirydate_end] unless params[:expirydate_end].blank?
    params_hash[:createdate_start] = params[:createdate_start] unless params[:createdate_start].blank?
    params_hash[:createdate_end] = params[:createdate_end] unless params[:createdate_end].blank?
    params_hash[:cond] = params[:cond] unless params[:cond].blank?
    params_hash[:title_id] = params[:title_id] unless params[:title_id].blank?
    params_hash[:limit] = params[:limit] unless params[:limit].blank?
    params_hash[:category] = params[:category] unless params[:category].blank?
    params_hash[:yyyy] = params[:yyyy] unless params[:yyyy].blank?
    params_hash[:mm] = params[:mm] unless params[:mm].blank?
    params_hash[:grp] = params[:grp] unless params[:grp].blank?
    params_hash[:sort_key] = sort_key unless sort_key.blank?
    params_hash[:order] = order unless order.blank?
    return params_hash
  end

  def get_current_group_name(group_id)
    return System::Group.where(code: group_id).first.name
  end
end
