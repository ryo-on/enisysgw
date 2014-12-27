# coding: utf-8
require 'net/http'

# === Apiへのリクエストを行う抽象クラス
#   継承先のクラスでApiへのリクエストを簡易にするためのクラス
class Rumi::AbstractApi

  # === Apiへのリクエストメソッド
  #  action_urlにGETするメソッド
  # ==== 引数
  #  * uri: action_urlのURI(URIオブジェクト)
  #  * action_url: ホスト名移行のアクションURL
  #  * queries: action_urlに付加するquery
  # ==== 戻り値
  #  APIへのリクエスト結果
  def request_api(uri, action_url, queries)
    # APIへアクセスする。
    query = queries.map{ |k, v| "#{CGI::escape(k.to_s)}=#{CGI::escape(v)}" }.join("&")
    action_url = [action_url, query].join("?")

    http = Net::HTTP.new(uri.host, uri.port)
    if uri.port == 443
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    begin
      return response_parse(http.start { http.get(action_url) })
    rescue => e
      # リクエストに失敗した場合はnilを返す
      return nil
    end
  end

  # === レスポンスに応じてRubyオブジェクトを成形するメソッド
  #  JSONの場合はparseさせる
  # ==== 引数
  #  * res: Response
  # ==== 戻り値
  #  Responseのbody
  def response_parse(res)
    return nil unless (200..399).include?(res.code.to_i)

    if res.content_type == Mime::JSON
      return JSON.parse(res.body)
    else
      return res.body.force_encoding("UTF-8")
    end
  end

end
