# -*- encoding: utf-8 -*-
class Doclibrary::Admin::MenusController < Gw::Controller::Admin::Base
  include Gwboard::Controller::Scaffold
  include Doclibrary::Model::DbnameAlias
  include Rumi::Doclibrary::Authorize

  layout "admin/template/portal_1column"

  def initialize_scaffold
    Page.title = I18n.t('activerecord.models.doclibrary/category')
    @css = ["/_common/themes/gw/css/doclibrary.css"]
    params[:limit] = 100
  end

  def index
    admin_flags('_menu')
    if @is_sysadm
      admin_index
    else
      readable_index
    end
  end

  def admin_index
    item = Doclibrary::Control.new
    item.and :state, 'public'
    item.and :view_hide, 1
    item.page params[:page], params[:limit]
    @items = item.find(:all, :order => 'sort_no, docslast_updated_at DESC, updated_at DESC')
  end

  # === 閲覧可能ファイル管理の取得メソッド
  #  本メソッドは、閲覧可能なファイル管理を取得するメソッドである。
  # ==== 引数
  #  なし
  # ==== 戻り値
  #  なし
  def readable_index
    # ログインユーザーの所属グループIDを取得（親グループを含む）
    user_group_parent_ids = Site.user.user_group_parent_ids

    # 管理権限のあるファイル管理のID取得
    admin_item = Doclibrary::Control.new
    admin_item.and "doclibrary_controls.state", "public"
    admin_item.and "doclibrary_controls.view_hide", 1
    admin_item.and do |d|
      # 管理部門に関する条件
      d.or do |d2|
        d2.and "doclibrary_adms.user_id", 0
        d2.and "doclibrary_adms.group_id", user_group_parent_ids
      end

      # 管理者に関する条件
      d.or do |d2|
        d2.and "doclibrary_adms.user_id", Site.user.id
      end
    end
    admin_item.join "INNER JOIN doclibrary_adms ON doclibrary_controls.id = doclibrary_adms.title_id"
    admin_control_ids = admin_item.find(:all).map(&:id)

    # 閲覧権限のあるファイル管理のID取得
    reader_item = Doclibrary::Control.new
    reader_item.and "doclibrary_controls.state", "public"
    reader_item.and "doclibrary_controls.view_hide", 1
    reader_item.and do |d|
      # 閲覧権限「制限なし」に関する条件
      d.or do |d2|
        d2.and "doclibrary_roles.role_code", "r"
        d2.and "doclibrary_roles.group_id", 0
      end

      # 閲覧部門に関する条件
      d.or do |d2|
        d2.and "doclibrary_roles.role_code", "r"
        d2.and "doclibrary_roles.group_id", user_group_parent_ids
      end

      # 閲覧者に関する条件
      d.or do |d2|
        d2.and "doclibrary_roles.role_code", "r"
        d2.and "doclibrary_roles.user_id", Site.user.id
      end
    end
    reader_item.join "INNER JOIN doclibrary_roles ON doclibrary_controls.id = doclibrary_roles.title_id "
    reader_control_ids = reader_item.find(:all).map(&:id)

    # IDからファイル管理を取得
    readable_ids = (admin_control_ids + reader_control_ids).uniq.join(",")
    @items = []
    unless readable_ids.blank?
      @items = Doclibrary::Control.where("id IN (#{readable_ids})")
                                  .order("sort_no , docslast_updated_at DESC")
                                  .limit(params[:limit])
                                  .page(params[:page])
    end
  end

end
