# encoding: utf-8
class Gw::Admin::PortalController < Gw::Controller::Admin::Base
  include System::Controller::Scaffold
  layout "admin/template/portal"

  def initialize_scaffold
    Page.title = I18n.t("rumi.top_page.name")
  end

  def index
    session[:request_fullpath] = request.fullpath
  end
end
