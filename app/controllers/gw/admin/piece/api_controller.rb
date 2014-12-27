# coding: utf-8
class Gw::Admin::Piece::ApiController < System::Admin::ApiController
  include Sys::Controller::Admin::Auth
  layout 'base'

  # === ヘッダーメニュー取得メソッド取得API
  #  ヘッダーのアイコン情報等を返却する
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  ヘッダーメニュー(HTML)
  def header_menus
    state, text = api_checker_login_post(params[:account], params[:password])

    if state == 200
      @items = Gw::EditLinkPiece.extract_location_header
    else
      @items = []
    end
  end

  def mail_admin
    state, text = api_checker_login_post(params[:account], params[:password])
    user_id = params[:id]
    @admin = System::Role.has_auth?(user_id, "_admin", "admin")
    @mail_admin = System::Role.has_auth?(user_id, "mail_admin", "admin")
  end

end
