# coding: utf-8
class Rumi::WebmailApi < Rumi::AbstractApi

  # === メール機能へのシングル・サインオンURL生成メソッド
  #
  # ==== 引数
  #  * user_code: ユーザーのコード
  #  * password: ユーザーのパスワード
  #  * path: リダイレクト先
  # ==== 戻り値
  #  リダイレクト先へのURL
  def login(user_code, password, path)
    url = Enisys::Config.application["webmail.root_url"]
    return nil if url.blank?

    action_url = "/_admin/air_sso"
    queries = { account: user_code, password: password }
    res = request_api(URI.parse(url), action_url, queries)

    if res.present? && res =~ /^OK/i
      second_queries = { account: user_code, token: res.gsub(/^OK /i, ""), path: path }
      query = second_queries.map{ |k, v| "#{CGI::escape(k.to_s)}=#{CGI::escape(v)}" }.join("&")

      return URI.join(url, [action_url, query].join("?")).to_s
    else
      return nil
    end
  end

  # === 未読メール情報取得メソッド
  #  新着情報に表示する未読状態メールを取得する
  # ==== 引数
  #  * user_code: ユーザーのコード
  #  * password: ユーザーのパスワード
  #  * sort_key: 並び替えするKey（日付／概要）
  #  * order: 並び順（昇順／降順）
  # ==== 戻り値
  #  APIへのリクエスト結果(Hashオブジェクト)
  def remind(user_code, password, sort_key, order)
    url = Enisys::Config.application["webmail.root_url"]
    return nil if url.blank?

    action_url = "/_api/gw/webmail/remind"
    queries = {
      account: user_code, password: password,
      sort_key: sort_key, order: order
    }

    res = request_api(URI.parse(url), action_url, queries)
    if res.present? && res.is_a?(Hash)
      res.symbolize_keys!
      res[:factors].each{ |factor| factor.symbolize_keys! } if res.key?(:factors)
    else
      res = {}
    end

    return res
  end

  # === 通知件数取得メソッド
  #  未読状態メールの件数を取得する
  # ==== 引数
  #  * user_code: ユーザーのコード
  #  * password: ユーザーのパスワード
  # ==== 戻り値
  #  通知件数(整数)
  def notification(user_code, password)
    res = self.remind(user_code, password, "datetime", "desc")
    if res.present?
      return res[:total_count]
    else
      return 0
    end
  end

  class << self

    # Rumi::WebmailApi#remindの呼び出し元メソッド
    def remind(user_code, password, sort_key, order)
      return self.new.remind(user_code, password, sort_key, order)
    end

    # Rumi::WebmailApi#notificationの呼び出し元メソッド
    def notification(user_code, password)
      return self.new.notification(user_code, password)
    end

    # Rumi::WebmailApi#loginの呼び出し元メソッド
    def login(user_code, password, path)
      return self.new.login(user_code, password, path)
    end

  end

end
