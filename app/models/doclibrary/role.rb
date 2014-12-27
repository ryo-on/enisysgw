class Doclibrary::Role < Gw::Database
  include System::Model::Base
  include System::Model::Base::Content

  # === ファイル管理の権限判定メソッド
  #  ファイル管理に対する権限を判定するメソッドである。
  # ==== 引数
  #  * title_id: タイトルID（ファイル管理ID）
  #  * user_id: ユーザーID
  #  * role_code: 権限コード（'w':編集権限 / 'r':閲覧権限）
  # ==== 戻り値
  #  true:権限あり / false:権限無し
  def self.has_auth?(title_id, user_id, role_code)
    # 編集権限はDoclibrary::Roleで管理しなくなったため、falseを返す
    return false if role_code == 'w'

    # ユーザーが対象に含まれる権限があるか？
    role = System::User.find(user_id).doclibrary_role(title_id, role_code)

    # 権限が設定されている場合はtrue、設定されていない場合はfalseを返す
    return (role.present?)? true : false
  end
end
