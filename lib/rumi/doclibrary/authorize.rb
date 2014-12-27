# coding: utf-8

# === ファイル管理用アクセス権関連モジュール
# 本モジュールは、ファイル管理用のアクセス権関連モジュールである。
module Rumi::Doclibrary::Authorize

  # === 権限フラグ設定メソッド（ファイル一覧表示）
  #  ファイル一覧表示に関する権限フラグを設定するメソッドである。
  # ==== 引数
  #  なし
  # ==== 戻り値
  #  なし
  def get_role_index
    admin_flags(@title.id)
    get_readable_flag
    set_has_some_folder_admin_flag
  end

  # === 権限フラグ設定メソッド（ファイル閲覧）
  #  ファイル閲覧に関する権限フラグを設定するメソッドである。
  # ==== 引数
  #  * item: Doclibrary::Docオブジェクト
  # ==== 戻り値
  #  なし
  def get_role_show(item)
    admin_flags(@title.id)
    get_readable_flag
    set_has_some_folder_admin_flag
  end

  # === 権限フラグ設定メソッド（ファイル編集）
  #  ファイル編集に関する権限フラグを設定するメソッドである。
  # ==== 引数
  #  * item: Doclibrary::Docオブジェクト
  # ==== 戻り値
  #  なし
  def get_role_edit(item)
    admin_flags(@title.id)
    set_has_some_folder_admin_flag
  end

  # === 権限フラグ設定メソッド（ファイル新規作成）
  #  ファイル新規作成に関する権限フラグを設定するメソッドである。
  # ==== 引数
  #  * item: Doclibrary::Docオブジェクト
  # ==== 戻り値
  #  なし
  def get_role_new
    admin_flags(@title.id)
    set_has_some_folder_admin_flag
  end
end