# coding: utf-8
class Gw::Admin::UserPasswordsController < Gw::Controller::Admin::Base
  layout "admin/template/admin"

  before_filter :initialize_scaffold, :set_user

  # === ページ設定 action
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def initialize_scaffold
    Page.title = I18n.t("rumi.config_settings.user_passwords.name")
  end

  # === パスワード更新画面 action
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def edit
  end

  # === パスワード更新 action
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def update
    # パスワード変更に関係する項目のみ
    user_params = params[:system_user]
    @user.old_password = user_params[:old_password]
    @user.new_password = user_params[:new_password]
    @user.new_password_confirmation = user_params[:new_password_confirmation]

    begin
      ActiveRecord::Base.transaction do
        @user.save!(context: :update_user_password)
        @user.update_new_user_password!

        respond_to do |format|
          # 強制ログアウトが発生する
          format.html { redirect_to root_url }
        end
      end
    rescue => e
      respond_to do |format|
        format.html { render action: :edit }
      end
    end

  end

  private

    # === ログインユーザーのインスタンスをセットするメソッド
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  なし
    def set_user
      @user = System::User.where(id: Core.user.id).first
    end

end
