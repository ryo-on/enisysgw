# encoding: utf-8
class Gwbbs::Admin::MenusController < Gw::Controller::Admin::Base
  include Gwboard::Controller::Scaffold
  include Gwbbs::Model::DbnameAlias
  include Gwboard::Controller::Authorize

  layout :select_layout
  protect_from_forgery :except => [:forward_select]

  def pre_dispatch
    Page.title = "掲示板"
    @css = ["/_common/themes/gw/css/bbs.css"]
  end

  def index
    admin_flags('_menu')
    if @is_sysadm
      admin_index
    else
      readable_index
    end
  end

  def forward_select
    admin_flags('_menu')
    @gwbbs_form_url = "/gwbbs/docs/forward"
    @gwbbs_target_name = "gwbbs_form"

    if @is_sysadm
      admin_index
    else
      writeable_index
    end
  end

  def admin_index
    item = Gwbbs::Control.new
    item.and :state, 'public'
    item.and :view_hide, 1
    item.page params[:page], params[:limit]
    @items = item.find(:all, :order => 'sort_no, docslast_updated_at DESC')
  end

  def readable_index
    sql = Condition.new
    sql.or {|d|
      d.and :state, 'public'
      d.and :view_hide , 1
      # 閲覧権限または、管理者権限が存在すること
      d.and "sql", "(gwbbs_roles.role_code = 'r' AND gwbbs_roles.group_code = '0' OR gwbbs_adms.group_id IS NOT NULL AND gwbbs_adms.group_code = '0')"
    }
    for group in Site.user.groups
      sql.or {|d|
        d.and :state, 'public'
        d.and :view_hide , 1
        # 閲覧権限または、管理者権限が存在すること
        d.and "sql", "(gwbbs_roles.role_code = 'r' AND gwbbs_roles.group_code = '#{group.code}' OR gwbbs_adms.group_id IS NOT NULL AND gwbbs_adms.group_code = '#{group.code}')"
      }

      unless group.parent.blank?
        sql.or {|d|
          d.and :state, 'public'
          d.and :view_hide , 1
          # 閲覧権限または、管理者権限が存在すること
          d.and "sql", "(gwbbs_roles.role_code = 'r' AND gwbbs_roles.group_code = '#{group.parent.code}' OR gwbbs_adms.group_id IS NOT NULL AND gwbbs_adms.group_code = '#{group.parent.code}')"
        }
      end
    end

    sql.or {|d|
      d.and :state, 'public'
      d.and :view_hide , 1
      # 閲覧権限または、管理者権限が存在すること
      d.and "sql", "(gwbbs_roles.role_code = 'r' AND gwbbs_roles.user_code = '#{Site.user.code}' OR gwbbs_adms.user_code = '#{Site.user.code}')"
    }
    join = "LEFT JOIN gwbbs_roles ON gwbbs_controls.id = gwbbs_roles.title_id LEFT JOIN gwbbs_adms ON gwbbs_controls.id = gwbbs_adms.title_id"
    item = Gwbbs::Control.new
    item.page   params[:page], params[:limit]
    @items = item.find(:all, :joins=>join, :conditions=>sql.where,:order => 'sort_no, docslast_updated_at DESC', :group => 'gwbbs_controls.id')
  end

  def writeable_index
    sql = Condition.new
    sql.or {|d|
      d.and :state, 'public'
      d.and :view_hide , 1
      # 編集権限または、管理者権限が存在すること
      d.and "sql", "(gwbbs_roles.role_code = 'w' AND gwbbs_roles.group_code = '0' OR gwbbs_adms.group_id IS NOT NULL AND gwbbs_adms.group_code = '0')"
    }
    for group in Site.user.groups
      sql.or {|d|
        d.and :state, 'public'
        d.and :view_hide , 1
        # 編集権限または、管理者権限が存在すること
        d.and "sql", "(gwbbs_roles.role_code = 'w' AND gwbbs_roles.group_code = '#{group.code}' OR gwbbs_adms.group_id IS NOT NULL AND gwbbs_adms.group_code = '#{group.code}')"
      }

      unless group.parent.blank?
        sql.or {|d|
          d.and :state, 'public'
          d.and :view_hide , 1
          # 編集権限または、管理者権限が存在すること
          d.and "sql", "(gwbbs_roles.role_code = 'w' AND gwbbs_roles.group_code = '#{group.parent.code}' OR gwbbs_adms.group_id IS NOT NULL AND gwbbs_adms.group_code = '#{group.parent.code}')"
        }
      end
    end

    sql.or {|d|
      d.and :state, 'public'
      d.and :view_hide , 1
      # 編集権限または、管理者権限が存在すること
      d.and "sql", "(gwbbs_roles.role_code = 'w' AND gwbbs_roles.user_code = '#{Site.user.code}' OR gwbbs_adms.user_code = '#{Site.user.code}')"
    }
    join = "LEFT JOIN gwbbs_roles ON gwbbs_controls.id = gwbbs_roles.title_id LEFT JOIN gwbbs_adms ON gwbbs_controls.id = gwbbs_adms.title_id"
    item = Gwbbs::Control.new
    item.page   params[:page], params[:limit]
    @items = item.find(:all, :joins=>join, :conditions=>sql.where,:order => 'sort_no, docslast_updated_at DESC', :group => 'gwbbs_controls.id')
  end

protected

  def select_layout
    layout = "admin/template/portal_1column"
    case params[:action].to_sym
    when :forward_select
      layout = "admin/template/mail_forward"
    end
    layout
  end
end
