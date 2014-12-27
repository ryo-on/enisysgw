# coding: utf-8
class Rumi::PieceApi < Rumi::AbstractApi

  # === ヘッダーメニュー取得メソッド
  #  ヘッダーのアイコン情報等を取得する
  # ==== 引数
  #  * uri: URI
  #  * user_code: ユーザーのコード
  #  * password: ユーザーのパスワード
  # ==== 戻り値
  #  APIへのリクエスト結果(Stringオブジェクト)
  def header_menus(uri, user_code, password)
    action_url = "/api/header_menus"
    queries = { account: user_code, password: password }

    return request_api(uri, action_url, queries)
  end

  class << self

    # Rumi::PieceApi#header_menusの呼び出し元メソッド
    def header_menus(uri, user_code, password)
      return self.new.header_menus(uri, user_code, password)
    end
  end

end
