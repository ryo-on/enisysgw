class Doclibrary::Adm < Gw::Database
  include System::Model::Base
  include System::Model::Base::Content

  # === ファイル管理の管理者権限判定メソッド
  #  ファイル管理に対する管理者権限を判定するメソッドである。
  # ==== 引数
  #  * title_id: タイトルID（ファイル管理ID）
  #  * user_id: ユーザーID
  # ==== 戻り値
  #  true:管理者権限あり / false:管理者権限無し
  def self.has_auth?(title_id, user_id)
    # ユーザーが対象に含まれる管理者権限があるか？
    role = System::User.find(user_id).doclibrary_admin_role(title_id)

    # 管理者権限が設定されている場合はtrue、設定されていない場合はfalseを返す
    return (role.present?)? true : false
  end
end
