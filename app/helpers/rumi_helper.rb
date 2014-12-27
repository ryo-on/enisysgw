# coding: utf-8
module RumiHelper

  # RumiHelper#build_select_parent_groupsで使用するoptions
  PARENT_GROUP_SETTINGS = {
    default: {
      without_disable: true,
      include_no_limit: false
    },
    include_no_limit: {
      without_disable: true,
      include_no_limit: true
    },
    system_role: {
      without_disable: false,
      include_no_limit: false
    }
  }

  # get_users アクションへのURL
  GET_USERS_URL = "/_admin/gwboard/ajaxgroups/get_users.json"

  # shared/select_group で利用する get_users アクションへのparams
  GET_USERS_SETTINGS = {
    default: {
      s_genre: "group_id",
      without_level_no_2_organization: true,
      without_schedule_authority_user: false
    },
    schedule: {
      s_genre: "group_id",
      without_level_no_2_organization: true,
      without_schedule_authority_user: true
    }
  }

  # get_child_groups アクションへのURL
  GET_CHILD_GROUPS_URI = "/_admin/gwboard/ajaxgroups/get_child_groups.json"

  # shared/select_group で利用する get_child_groups アクションへのparams
  GET_CHILD_GROUPS_SETTINGS = {
    default: {
      s_genre: "group_id",
      without_disable: true
    },
    system_role: {
      s_genre: "group_id",
      without_disable: false
    }
  }

  # === 通常のグループ選択UI Modeのシンボルを返す
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  Symbol
  def ui_mode_groups_default
    return :groups_default
  end

  # === 制限なしを選択肢に含むグループ選択UI Modeのシンボルを返す
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  Symbol
  def ui_mode_groups_include_no_limit
    return :groups_include_no_limit
  end

  # === カスタムグループ用のグループ選択UI Modeのシンボルを返す
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  Symbol
  def ui_mode_groups_custom_group
    return :groups_custom_group
  end

  # === 権限設定 管理グループ用のグループ選択UI Modeのシンボルを返す
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  Symbol
  def ui_mode_groups_system_role
    return :groups_system_role
  end

  # === グループ選択UI Modeか判定する
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  boolean
  def ui_mode_groups?(ui_mode)
    return [ui_mode_groups_default, ui_mode_groups_include_no_limit,
      ui_mode_groups_custom_group, ui_mode_groups_system_role].include?(ui_mode)
  end

  # === 通常のユーザー選択UI Modeのシンボルを返す
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  Symbol
  def ui_mode_users_default
    return :users_default
  end

  # === カスタムグループ用のユーザー選択UI Modeのシンボルを返す
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  Symbol
  def ui_mode_users_custom_group
    return :users_custom_group
  end

  # === スケジュール用のユーザー選択UI Modeのシンボルを返す
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  Symbol
  def ui_mode_users_schedule
    return :users_schedule
  end

  # === ユーザー選択UI Modeか判定する
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  boolean
  def ui_mode_users?(ui_mode)
    return [ui_mode_users_default, ui_mode_users_custom_group, ui_mode_users_schedule].include?(ui_mode)
  end

  # === 新着情報に表示する概要文が40文字（デフォルト）以上の時、文字を切り捨てるメソッド
  #  概要文(上限40文字) + " が○○されました。"  
  # ==== 引数
  #  * category: 機能を表すsymbol
  #  * action: 概要文に付加する操作を表すsymbol
  #  * title: 概要文
  #  * word_count: 文字数
  # ==== 戻り値
  #  概要文 + 概要文に付加する操作
  #    例: メール題名 を受信しました。
  def truncate_remind_title(category, action, title, word_count = 40)
    sep = title.length > word_count ? "... " : " "
    return truncate(title, length: word_count, omission: "") + sep + t(["rumi.reminder.feature", category, "action", action].join("."))
  end

  # === http://で始まるURLを生成するメソッド
  #  http://で始まるURLを返却する
  # ==== 引数
  #  * url: URL
  # ==== 戻り値
  #  http://で始まるURLを返却する
  def link_options_url(url)
    begin
      url = URI.parse(url)
    rescue
      # 有効なURLでなければnilを返す
      return nil
    else
      url = URI.join(root_url, url.to_s) unless url.host
      return url.to_s
    end
  end

  # === 通知件数表示のspanを生成するメソッド
  #  link_options[:url] で機能を判断する
  # ==== 引数
  #  * link_options: Gw::EditLinkPiece#link_options
  #  * user_code: ユーザーのコード
  #  * password: ユーザーのパスワード
  # ==== 戻り値
  #  通知件数表示のspan
  def span_notification_count(link_options, user_code, password)
    count = notification_count(link_options, user_code, password)
    content = ""
    if count.zero?
      return ""
    else
      count = "99+" if count > 99
      return %Q(<span class="noRead">#{count}</span>)
    end
  end

  # === 通知件数を取得するメソッド
  #  link_options[:url] で機能を判断する
  # ==== 引数
  #  * link_options: Gw::EditLinkPiece#link_options
  #  * user_code: ユーザーのコード
  #  * password: ユーザーのパスワード
  # ==== 戻り値
  #  通知件数
  def notification_count(link_options, user_code, password)
    url = link_options[:url]
    count = 0
    user_id = System::User.find_by_code(user_code).id

    # メール
    count = Rumi::WebmailApi.notification(user_code, password) if mail_feature_url?(url)
    # 回覧板
    count = Gwcircular::Control.notification(user_id) if circular_feature_url?(url)
    # 掲示板
    count = Gwbbs::Control.notification(user_id) if bbs_feature_url?(url)
    # スケジュール
    count = Gw::Schedule.normal_notification(user_id) if schedule_feature_url?(url)
    # 施設予約
    count = Gw::Schedule.prop_notification(user_id) if schedule_prop_feature_url?(url)
    # ファイル管理
    count = Doclibrary::Control.notification(user_id) if doclibrary_feature_url?(url)

    return count
  end

  # === メール機能のURLか判断するメソッド
  #
  # ==== 引数
  #  * url: URL
  # ==== 戻り値
  #  boolean
  def mail_feature_url?(url)
    return (url == Enisys::Config.application["webmail.root_url"])
  end

  # === 回覧板機能のURLか判断するメソッド
  #
  # ==== 引数
  #  * url: URL
  # ==== 戻り値
  #  boolean
  def circular_feature_url?(url)
    return url.include?("gwcircular")
  end

  # === 掲示板機能のURLか判断するメソッド
  #
  # ==== 引数
  #  * url: URL
  # ==== 戻り値
  #  boolean
  def bbs_feature_url?(url)
    return url.include?("gwbbs")
  end

  # === スケジュール機能のURLか判断するメソッド
  #
  # ==== 引数
  #  * url: URL
  # ==== 戻り値
  #  boolean
  def schedule_feature_url?(url)
    return url.include?("schedules")
  end

  # === 施設予約機能のURLか判断するメソッド
  #
  # ==== 引数
  #  * url: URL
  # ==== 戻り値
  #  boolean
  def schedule_prop_feature_url?(url)
    return url.include?("schedule_props")
  end

  # === ファイル管理機能のURLか判断するメソッド
  #
  # ==== 引数
  #  * url: URL
  # ==== 戻り値
  #  boolean
  def doclibrary_feature_url?(url)
    return url.include?("doclibrary")
  end

  # === リマインダーの各機能の見出しリンクを生成する
  #
  # ==== 引数
  #  * tiltes: 見出し
  #  * urls: リンク先
  # ==== 戻り値
  #  リンク
  def link_to_reminders_feature(titles, urls)
    links = ""
    unless titles.is_a?(Array) && urls.is_a?(Array)
      titles = ([titles]).flatten
      urls = ([urls]).flatten
    end

    titles.each_with_index do |title, i|
      url = urls[i]
      if url.present?
        links << link_to(title, url)
      else
        links << title
      end
    end

    return links.html_safe
  end

  # === Gwにおけるプロフィール画面へのリンクを生成する
  #
  # ==== 引数
  #  * display_name: ユーザー名(ユーザーコード)
  #  * user_code: ユーザーのコード
  # ==== 戻り値
  #  Gwにおけるプロフィール画面へのリンク
  def link_to_show_profile(display_name, user_code)
    return link_to(display_name, "/system/users/#{user_code}/show_profile")
  end

  # === 権限設定画面において管理グループUIを活性／非活性にするメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  評価前の文字列(JavaScriptで評価するため)
  def disabled_system_editable_group?
    role = System::RoleName.system_users_role.try(:id)
    priv = System::PrivName.editor.try(:id)

    if role && priv
      return "(Number($('item_role_name_id').value) == #{role} && Number($('item_priv_user_id').value) == #{priv})"
    else
      return "false"
    end
  end

  # === ユーザー選択UIの選択肢を返却する
  #
  # ==== 引数
  #  * users: System::User
  #  * value_method: Symbol e.g. :code
  # ==== 戻り値
  #  配列(options_for_selectで使用するため)
  def build_select_users(users, value_method = :id)
    return users.map { |user| user.to_select_option(value_method) }
  end

  # === 所属選択UIにて階層レベルを表す表現の選択肢を返却する
  #
  # ==== 引数
  #  * user_groups: System::UsersGroup
  #  * value_method: Symbol e.g. :code
  # ==== 戻り値
  #  配列(options_for_selectで使用するため)
  def build_select_user_groups(user_groups, value_method = :id)
    group_ids = user_groups.map(&:group_id)
    groups = System::Group.where(id: group_ids)

    return build_select_groups(groups, value_method)
  end

  # === 所属選択UIにて階層レベルを表す表現の選択肢を返却する
  #
  # ==== 引数
  #  * groups: System::Group
  #  * value_method: Symbol e.g. :code
  # ==== 戻り値
  #  配列(options_for_selectで使用するため)
  def build_select_groups(groups, value_method = :id)
    return groups.map { |group| group.to_select_option(value_method) }
  end

  # === 所属選択UIにて階層レベルを表す表現の選択肢を返却する
  #
  # ==== 引数
  #  * groups: System::Group || Gwcircular::CustomGroup || nil
  #  * options: Hash || nil
  #      e.g. without_disable: boolean, include_no_limit: boolean
  #  * value_method: Symbol e.g. :code
  # ==== 戻り値
  #  配列(options_for_selectで使用するため)
  def build_select_parent_groups(groups = nil, options = RumiHelper::PARENT_GROUP_SETTINGS[:default], value_method = :id)
    no_relation = groups.is_a?(Array)
    # 制限なしを表示するか
    include_no_limit = options.key?(:include_no_limit) && options[:include_no_limit] == true

    show_groups = []
    show_groups << System::Group.no_limit_group if include_no_limit

    if no_relation
      show_groups << groups.to_a
    else
      # 無効なグループを表示するか
      without_disable = options.key?(:without_disable) && options[:without_disable] == true

      groups = System::Group.order(:id) if groups.nil?
      groups = groups.without_disable if without_disable

      # System::Groupの場合
      if groups.first.is_a?(System::Group)
        # 階層レベル2, 3のみ
        groups = groups.without_root
        # 階層レベル、グループIDの昇順でソートする
        groups.extract_level_no_2.each do |level_2_group|
          show_groups << level_2_group
          show_groups << groups.where(parent_id: level_2_group.id).to_a
        end
      # その他、Gwcircular::CustomGroupの場合
      else
        show_groups << groups.to_a
      end
    end

    return build_select_groups(show_groups.flatten.compact, value_method)
  end

  # === 閲覧画面で所属を縦表示するメソッド
  #
  # ==== 引数
  #  * groups: Array
  # ==== 戻り値
  #  string(HTML)
  def build_vertical_group(groups)
    names = []
    if groups.present?
      if groups.first.is_a? System::Group
        names = groups.map(&:name)
      else
        # TODO: groups.first.size == 3
        # [code, id, name]
        names = groups.map { |record| record.group.name }
      end
    end

    return names.join("<br>")
  end

  # === 最新のグループ名、codeにするメソッド
  #
  # ==== 引数
  #  * values: string(JSON形式)
  # ==== 戻り値
  #  string(JSON形式)
  def update_select_group_values(values)
    return nil if values.blank?

    group_infos = JsonParser.new.parse(values)
    show_values = group_infos.map do |group_info|
      origin_group = System::Group.where(id: group_info[1]).first
      # 制限なしの場合
      origin_group = System::Group.no_limit_group if origin_group.blank? && System::Group.no_limit_group_id?(group_info[1])
      if origin_group
        origin_group.to_json_option
      else
        # 予期せぬデータの場合
        group_info
      end
    end

    return show_values.to_s
  end

  # === 最新のユーザー名、codeにするメソッド
  #
  # ==== 引数
  #  * values: string(JSON形式)
  # ==== 戻り値
  #  string(JSON形式)
  def update_select_user_values(values)
    return nil if values.blank?

    user_infos = JsonParser.new.parse(values)
    show_values = user_infos.map do |user_info|
      origin_user = System::User.where(id: user_info[1]).first
      if origin_user
        origin_user.to_json_option
      else
        # 予期せぬデータの場合
        user_info
      end
    end

    return show_values.to_s
  end

  # === 閲覧画面で配置場所を表示するメソッド
  #
  # ==== 引数
  #  * location: 数値
  # ==== 戻り値
  #  文字列
  def build_link_piece_location(location)
    return Gw.yaml_to_array_for_select("link_piece_locations")[location.to_i - 1].first
  end

  # === 所属選択UIにてIDの重複がないようにuniqな文字列を返却する
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  文字列(a-zの内20文字がランダムで入る)
  def create_uniq_id
    return ("a".."z").to_a.sample(20).join
  end

  # === 所属選択UIにてフォーム送信するitem名をIDにした場合の文字列を返却する
  #
  # ==== 引数
  #  * item_name: 文字列 e.g. item[editable_groups_json]
  # ==== 戻り値
  #  文字列 e.g. item_editable_groups_json
  def trim_form_item_name(item_name)
    return item_name.sub(/\[/, "_").sub(/\]/, "")
  end

  # === アンダーバーで文字列を結合するメソッド
  #
  # ==== 引数
  #  * args: 複数の文字列
  # ==== 戻り値
  #  文字列
  def join_underbar(*args)
    return args.to_a.join("_")
  end

  # === テーブルが無いがvalidationを実行したいフォームに対応するクラス
  #
  class ActiveForm
    include ActiveModel::Validations
    include ActiveModel::Conversion
    extend  ActiveModel::Naming

    # === 初期化
    #
    # ==== 引数
    #  * attributes: Hash
    # ==== 戻り値
    #  ActiveFormクラスのインスタンス
    def initialize(attributes = nil)
      # Mass Assignment implementation
      if attributes
        attributes.each do |key, value|
          self[key] = value
        end
      end
      yield self if block_given?
    end

    # === Getter
    #
    # ==== 引数
    #  * key: Attr名
    # ==== 戻り値
    #  Attr名のインスタンス変数の値
    def [](key)
      instance_variable_get("@#{key}")
    end

    # === Setter
    #
    # ==== 引数
    #  * key: Attr名
    # ==== 戻り値
    #  なし
    def []=(key, value)
      instance_variable_set("@#{key}", value)
    end

    # === 未保存のレコードか?
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  常にtrue
    def new_record?
      true
    end

    # === idのgetter
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  常にnil
    def id
      nil
    end

  end

  # === CSV出力、CSV仮登録画面のフォームに使用するクラス
  #
  class CsvForm < ActiveForm
    CSV_MODES = ["put", "up"]
    NKF_VALUES = ["utf8", "sjis"]

    # 許可するattr
    attr_accessor :csv, :nkf, :file

    validates :csv, inclusion: { in: RumiHelper::CsvForm::CSV_MODES }
    validates :nkf, inclusion: { in: RumiHelper::CsvForm::NKF_VALUES }
    # CSV仮登録画面の時は必須とする
    validates :file, presence: true, if: Proc.new{ |record| record.import_mode? }
    validate :ext_name_valid, if: Proc.new{ |record| record.import_mode? && file.present? }

    # === 拡張子の検証
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  なし
    def ext_name_valid
      ext_name = File.extname(file.original_filename)
      errors.add :file, I18n.t("rumi.rumi_helper.csv_form.file.message.invalid") if ".csv" != ext_name
    end

    # === CSV出力画面か?
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  boolean
    def export_mode?
      return self.csv == RumiHelper::CsvForm.export_mode
    end

    # === CSV仮登録画面か?
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  boolean
    def import_mode?
      return self.csv == RumiHelper::CsvForm.import_mode
    end

    # === utf8か?
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  boolean
    def utf8?
      return self.nkf == RumiHelper::CsvForm::NKF_VALUES.first
    end

    # === sjisか?
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  boolean
    def sjis?
      return self.nkf == RumiHelper::CsvForm::NKF_VALUES.last
    end

    class << self

      # === CSV出力画面のフォームの初期値を設定したものを返す
      #
      # ==== 引数
      #  * なし
      # ==== 戻り値
      #  CsvFormのインスタンス
      def new_export_mode
        return RumiHelper::CsvForm.new(
          csv: RumiHelper::CsvForm.export_mode,
          nkf: RumiHelper::CsvForm::NKF_VALUES.last)
      end

      # === CSV仮登録画面のフォームの初期値を設定したものを返す
      #
      # ==== 引数
      #  * なし
      # ==== 戻り値
      #  CsvFormのインスタンス
      def new_import_mode
        return RumiHelper::CsvForm.new(
          csv: RumiHelper::CsvForm.import_mode,
          nkf: RumiHelper::CsvForm::NKF_VALUES.last)
      end

      # === CSV出力画面モード
      #
      # ==== 引数
      #  * なし
      # ==== 戻り値
      #  string
      def export_mode
        RumiHelper::CsvForm::CSV_MODES.first
      end

      # === CSV仮登録画面モード
      #
      # ==== 引数
      #  * なし
      # ==== 戻り値
      #  string
      def import_mode
        RumiHelper::CsvForm::CSV_MODES.last
      end
    end

  end

  # === ログアウト時に遷移するURLを生成する
  # === 
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  ログアウト時に遷移するURL
  def make_logout_url
    url = Enisys::Config.application["webmail.root_url"]
    
    if url.blank?
      return '/_admin/login'
    else
      begin
        logout_url = URI.join(url, "/_admin/logout").to_s
      rescue
        return '/_admin/login'
      else
        return logout_url
      end
    end
  end
  
end
