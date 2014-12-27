# encoding: utf-8
class System::RoleName < ActiveRecord::Base
  include System::Model::Base
  include System::Model::Base::Config

  validates_presence_of :display_name, :table_name, :sort_no
  validates_uniqueness_of :table_name, :display_name
  validates_numericality_of :sort_no

  def editable?
    return true
  end

  def deletable?
    return false if System::Role.find_by_role_name_id(id)
    return false if System::RoleNamePriv.find_by_role_id(id)
    return true
  end

  class << self

    # === ユーザー・グループ管理(system_users)の権限レコードを返却するメソッド
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  System::RoleName
    def system_users_role
      System::RoleName.where(table_name: "system_users").first
    end

  end

end
