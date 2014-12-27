# -*- encoding: utf-8 -*-

class Gwcircular::Admin::Piece::MenusController < ApplicationController
  include Gwboard::Controller::Scaffold
  include Gwboard::Controller::Common
  include Gwcircular::Model::DbnameAlias
  include Gwcircular::Controller::Authorize

  def initialize_scaffold
    skip_layout
    params[:title_id] = 1
    @title = Gwcircular::Control.find_by_id(params[:title_id])
    return http_error(404) unless @title
  end

  def index
    params[:category] = 'EXPIRY' if params[:category].blank? && (params[:cond] != 'owner' && params[:cond] != 'admin')
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
  end

  def unread_index
    @groups = Gwcircular::Doc.unread_info(@title.id).select_createrdivision_info
    @monthlies = Gwcircular::Doc.unread_info(@title.id).select_monthly_info
  end

  def already_read_index
    @groups = Gwcircular::Doc.already_info(@title.id).select_createrdivision_info
    @monthlies = Gwcircular::Doc.already_info(@title.id).select_monthly_info
  end

  def owner_index
    @groups = Gwcircular::Doc.owner_info(@title.id).select_createrdivision_info
    @monthlies = Gwcircular::Doc.owner_info(@title.id).select_monthly_info
  end

  def admin_index
    @groups = Gwcircular::Doc.admin_info(@title.id).select_createrdivision_info
    @monthlies = Gwcircular::Doc.admin_info(@title.id).select_monthly_info
  end
end
