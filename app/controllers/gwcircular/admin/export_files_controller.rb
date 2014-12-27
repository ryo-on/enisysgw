# -*- encoding: utf-8 -*-
class Gwcircular::Admin::ExportFilesController < Gw::Controller::Admin::Base
  include System::Controller::Scaffold

  rescue_from ActionController::InvalidAuthenticityToken, :with => :invalidtoken

  def initialize_scaffold
    params[:title_id] = 1
    @title = Gwcircular::Control.find_by_id(params[:title_id])
    return http_error(404) unless @title
    @item = Gwcircular::Doc.find_by_id(params[:gwcircular_id])
    return http_error(404) unless @item
  end

  def index
    f_name = "gwcircular_#{Time.now.strftime('%Y%m%d%H%M%S')}.zip"
    f_name = params[:f_name] unless params[:f_name].blank?
    target_zip_file ="#{Rails.root}/tmp/gwcircular/#{f_name}"
    send_file target_zip_file if FileTest.exist?(target_zip_file)

    unless FileTest.exist?(target_zip_file)
      flash[:notice] = '出力対象の添付ファイルがありません。'
      redirect_to :back
      #redirect_to "/gwcircular/#{@item.id}/file_exports?#{params[:cond]}"
    end
  end

private
  def invalidtoken

  end
end