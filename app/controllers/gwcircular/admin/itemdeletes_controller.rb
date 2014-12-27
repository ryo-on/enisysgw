# -*- encoding: utf-8 -*-
class Gwcircular::Admin::ItemdeletesController < Gw::Controller::Admin::Base

  include Gwboard::Controller::Scaffold
  include Gwboard::Controller::Common
  include Gwcircular::Model::DbnameAlias
  include Gwcircular::Controller::Authorize

  layout "admin/template/gwcircular_base"

  def initialize_scaffold
    Page.title = "回覧板 削除設定"
    @css = ["/_common/themes/gw/css/circular.css"]

    check_gw_system_admin
    return authentication_error(403) unless @is_sysadm
  end

  def index
    item = Gwcircular::Itemdelete.new
    item.and :content_id, 0
    @item = item.find(:first)
  end

  def edit
    item = Gwcircular::Itemdelete.new
    item.and :content_id, 0
    @item = item.find(:first)
    return unless @item.blank?

    @item = Gwcircular::Itemdelete.create({
      :content_id => 0 ,
      :admin_code => Site.user.code ,
      :limit_date => '1.month'
    })
  end

  def update
    item = Gwcircular::Itemdelete.new
    item.and :content_id, 0
    @item = item.find(:first)
    return if @item.blank?
    @item.attributes = params[:item]
    location = config_url(:config_settings_sakujo)
    _update(@item, :success_redirect_uri=>location)
  end

protected

  def check_gw_system_admin
    @is_sysadm = true if Gw.is_admin_admin?
    @is_bbsadm = true if @is_sysadm
  end

end
