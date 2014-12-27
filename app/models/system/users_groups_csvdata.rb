# encoding: utf-8
class System::UsersGroupsCsvdata < ActiveRecord::Base
  include System::Model::Base
  include System::Model::Base::Config
  include System::Model::Base::Content
  belongs_to :parent, :foreign_key => :parent_id, :class_name => 'System::UsersGroupsCsvdata'
  has_many :children, :foreign_key => :parent_id, :class_name => 'System::UsersGroupsCsvdata'
  has_many :groups, :foreign_key => :parent_id, :class_name => 'System::UsersGroupsCsvdata',
    :conditions => { :data_type => "group" }
  has_many :users, :foreign_key => :parent_id, :class_name => 'System::UsersGroupsCsvdata',
    :conditions => { :data_type => "user" }

  has_one :user_profile, foreign_key: :user_id, class_name: "System::UsersGroupsCsvdataProfile", dependent: :destroy

  attr_accessor :origin_user

  # 種別
  DATA_TYPE_VALUES = ["group", "user"]
  # 階層レベル
  LEVEL_NO_VALUES = [2, 3]

  # ユーザー、ユーザー・グループ、グループ共通
  validates :code, :name, :start_at, :parent_id, presence: true
  validates :state, inclusion: { in: Proc.new{ |record| System::UsersGroup.state_values } }
  validates :ldap, inclusion: { in: Proc.new{ |record| System::UsersGroup.ldap_values } }
  # codeが入力されていた場合は、フォーマットのチェックを行う
  validate :code_valid, if: Proc.new { |record| record.code.present? }
  # メールアドレスが入力されていた場合は、フォーマットのチェックを行う
  validate :email_valid, if: Proc.new { |record| record.email.present? }
  # 9桁まで整数のみ許可する
  validates :sort_no, numericality: { only_integer: true,
    greater_than_or_equal_to: -999999999,  less_than_or_equal_to: 999999999 }
  # 開始日の検証
  validate :start_at_valid, if: Proc.new{ |record| record.start_at.present? }
  # 終了日の検証
  validate :end_at_valid, if: Proc.new{ |record| record.end_at.present? }
  # 同一所属配下でcodeの重複を許可しない
  #   グループの場合は親グループ配下に対するcodeの重複チェックとなる
  #   ユーザーの場合は所属グループに対するユーザーの重複チェックとなる
  validates :code, uniqueness: { scope: [:parent_id] }
  # 状態が無効の場合は入力必須
  validates :end_at, presence: true, if: Proc.new{ |record| record.disabled? }

  # グループの場合の検証
  validates :category, inclusion: { in: Proc.new{ |record| System::Group.category_values } },
    if: Proc.new{ |record| record.data_type_group? }
  # 状態が有効の場合は、親グループが有効でないと許可しない
  # 状態が無効の場合は、子グループが無効かつ、自身に対するユーザー・グループが存在しない時のみ許可する
  validate :group_state_valid, if: Proc.new { |record| record.data_type_group? }
  # 階層レベル2, 3のみ許可
  validates :level_no, inclusion: { in: System::UsersGroupsCsvdata::LEVEL_NO_VALUES }, if: Proc.new { |record| record.data_type_group? }

  # ユーザーの場合の検証
  # 状態が有効なユーザーを対象に本務が重複していないか検証する
  validate :job_order_valid, if: Proc.new{ |record|
    record.data_type_user? && record.enabled? && record.job_order == System::UsersGroup.job_order_key_role }
  validates :job_order, inclusion: { in: Proc.new{ |record| System::UsersGroup.job_order_values },
    if: Proc.new{ |record| record.data_type_user? && record.parent.present? && !record.parent.any_group? } }
  # LDAPが非同期の場合はパスワードが必須となる
  validates :password, presence: true,
    if: Proc.new { |record| record.data_type_user? && record.ldap == System::UsersGroup.ldap_values.first }
  # 所属グループは状態が有効なグループのみ許可する
  validate :parent_group_state_valid, if: Proc.new { |record| record.data_type_user? && record.parent.present? }

  # === デフォルトのorder。
  #  表示順 > コードの昇順 > レコードIDの昇順
  #
  default_scope { order("system_users_groups_csvdata.sort_no", "system_users_groups_csvdata.code", "system_users_groups_csvdata.id") }

  # === 有効なレコードのみ抽出するためのスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :without_disable, lambda {
    current_time = Time.now
    where(state: "enabled").where("start_at <= '#{current_time.strftime("%Y-%m-%d 00:00:00")}'").where(
      "end_at is null or end_at = '0000-00-00 00:00:00' or end_at > '#{current_time.strftime("%Y-%m-%d 23:59:59")}'")
  }

  # === 種別がグループのレコードのみ抽出するスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :extract_group, lambda {
    where(data_type: System::UsersGroupsCsvdata.group_data_type)
  }

  # === 種別がユーザーのレコードのみ抽出するスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :extract_user, lambda {
    where(data_type: System::UsersGroupsCsvdata.user_data_type)
  }

  # === 階層レベル2のレコードのみ抽出するためのスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :extract_level_no_2, where(level_no: 2)

  # === 階層レベル3のレコードのみ抽出するためのスコープ
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  抽出結果(ActiveRecord::Relation)
  scope :extract_level_no_3, where(level_no: 3)

  # === codeのフォーマット検証
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def code_valid
    errors.add :code, I18n.t("rumi.system.user.code.message.invalid") unless System::User.valid_user_code_characters?(code)
  end

  # === emailのフォーマット検証
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def email_valid
    errors.add :email unless Gw.is_simplicity_valid_email_address?(email)
  end

  # === start_atのフォーマット検証
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def start_at_valid
    local_start_at = Time.local(start_at.year, start_at.month, start_at.day, 0, 0, 0)
    local_now = Time.local(Time.now.year, Time.now.month, Time.now.day, 0, 0, 0)

    # 本日以前の日付を入力してください。
    errors.add :start_at, :invalid if local_start_at > local_now
  end

  # === end_atのフォーマット検証
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def end_at_valid
    local_start_at = Time.local(start_at.year, start_at.month, start_at.day, 0, 0, 0)
    local_end_at = Time.local(end_at.year, end_at.month, end_at.day, 0, 0, 0)
    local_now = Time.local(Time.now.year, Time.now.month, Time.now.day, 0, 0, 0)

    # 状態が「有効」の場合、空欄とし、本日以前かつ、開始日より後の日付を入力してください。
    errors.add :end_at, :invalid if self.enabled? || (local_end_at > local_now) || (start_at.present? && local_end_at < local_start_at)
  end

  # === 状態が有効なユーザーを対象に本務が重複していないか検証する
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def job_order_valid
    # 本務・兼務が本務かつ自分自身ではない有効状態のユーザー・グループ
    self_record_id = self.id
    enable_user_groups = System::UsersGroupsCsvdata.without_disable.extract_user.where(
      job_order: System::UsersGroup.job_order_key_role, code: self.code)
    job_order_key_role_user_group = enable_user_groups.select { |enable_user_group| enable_user_group.id != self_record_id }

    errors.add :job_order, I18n.t("rumi.system.user.job_order_0.message.unique") unless job_order_key_role_user_group.count.zero?
  end

  # === 状態が無効の場合は、子グループが無効かつ、自身に対するユーザー・グループが存在しないか検証する
  #     状態が有効の場合は、親グループが有効でないと許可しない
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def group_state_valid
    # 状態が無効の場合は、子グループが無効かつ、自身に対するユーザー・グループが存在しないか検証する
    errors.add :state, :child_group_enabled if disabled? && has_enable_child_or_users_group?
    # 状態が有効の場合は、親グループが有効でないと許可しない
    errors.add :state, :parent_group_disabled if enabled? && parent.present? && parent.disabled?
  end

  # === 状態が有効な子グループ、または自身に対するユーザー・グループが存在(有効、無効関係なく)するか判断するメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  boolean
  def has_enable_child_or_users_group?
    # 状態が有効な子グループ
    child_count = self.groups.without_disable.count
    # 自身に対するユーザー・グループ
    user_count = users.count

    return !child_count.zero? || !user_count.zero?
  end

  # === 所属グループは状態が有効なグループか検証する
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def parent_group_state_valid
    # 所属グループが有効でないと配属を許可しない
    errors.add :parent_id, :parent_group_disabled if parent.disabled?
  end

  # === 組織・任意が任意か評価するメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  boolean
  def any_group?
    return self.category == 1
  end

  # === 種別がグループを返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  boolean
  def data_type_group?
    return self.data_type == System::UsersGroupsCsvdata.group_data_type
  end

  # === 種別がユーザーを返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  boolean
  def data_type_user?
    return self.data_type == System::UsersGroupsCsvdata.user_data_type
  end

  # === エラーメッセージを一行で表した文字列を返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  エラーメッセージ
  def error_full_messages
    return errors.full_messages.join
  end

  # === 追加項目1の値を返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  追加項目1
  def add_column1
    return add_column(1)
  end

  # === 追加項目2の値を返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  追加項目2
  def add_column2
    return add_column(2)
  end

  # === 追加項目3の値を返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  追加項目3
  def add_column3
    return add_column(3)
  end

  # === 追加項目4の値を返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  追加項目4
  def add_column4
    return add_column(4)
  end

  # === 追加項目5の値を返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  追加項目5
  def add_column5
    return add_column(5)
  end

  # === 種別: グループを表す文字列
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  String
  def self.group_data_type
    return System::UsersGroupsCsvdata::DATA_TYPE_VALUES.first
  end

  # === 種別: ユーザーを表す文字列
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  String
  def self.user_data_type
    return System::UsersGroupsCsvdata::DATA_TYPE_VALUES.last
  end

  # === 階層レベル2か評価するメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  boolean
  def self.level_no_2?(level_no)
    return level_no == System::UsersGroupsCsvdata::LEVEL_NO_VALUES.first
  end

  # === ユーザー、グループ情報のCSVを返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  String
  def self.to_csv
    require 'csv'

    csv_string = CSV.generate(force_quotes: true) do |csv|
      csv << csv_header.values

      # 階層レベル2のグループ
      System::Group.extract_level_no_2.each do |level_no_2_group|
        level_no_2_group.to_csv(csv)
        # 階層レベル3のグループ
        level_no_2_group.children.each { |level_no_3_group| level_no_3_group.to_csv(csv) }
      end
    end

    return csv_string
  end

  # === ユーザー、グループ情報のCSVをImportするメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  Hash { invalid:検証が失敗したか, invalid_csv_array: エラーメッセージ入りのCSV }
  def self.import_csv(csv_string)
    require 'csv'

    begin
      # 仮データを削除
      System::UsersGroupsCsvdata.delete_all
      # rootグループを作成
      System::UsersGroupsCsvdata.create_root_group

      csv_array = CSV.parse(csv_string)
      # 返却用のCSVデータ
      invalid_csv_array = csv_array.dup
      # CSV Header
      csv_header_keys = csv_header.keys
      # エラー用項目のindex
      error_row_index = csv_header_keys.count
      # userまとめ用配列
      user_csv_hash_rows = []
      # groupまとめ用配列
      group_csv_hash_rows = []
      level_no_2_group_csv_hash_rows = []
      level_no_3_group_csv_hash_rows = []
      # 検証OKか
      has_invalid = false

      # 種別のエラーメッセージ
      data_type_error_message = System::UsersGroupsCsvdata.new
      data_type_error_message.errors.add(:data_type, :inclusion)
      data_type_error_message = data_type_error_message.error_full_messages
      # 階層レベルのエラーメッセージ
      level_no_error_message = System::UsersGroupsCsvdata.new
      level_no_error_message.errors.add(:level_no, :inclusion)
      level_no_error_message = level_no_error_message.error_full_messages

      # グループとユーザーでCSV情報を振り分ける
      csv_array.each_with_index do |row, i|
        # 最初の1行はHeaderなので無視し、エラー用項目を追加する
        if i.zero?
          invalid_csv_array.first[error_row_index] = "error"
          next
        else
          # 空の行も無視する。
          next if row.blank?

          # 扱いやすいようにHash化
          csv_hash_row = {}
          csv_header_keys.each_with_index { |key, n| csv_hash_row.store(key, row[n] || "") }
          # エラーメッセージを初期化
          invalid_csv_array[i][error_row_index] = ""

          case csv_hash_row[:data_type]
          # 種別: グループ
          when System::UsersGroupsCsvdata.group_data_type
            level_no = csv_hash_row[:level_no].to_i
            # 階層レベル2, 3以外のグループ(Error)
            unless System::UsersGroupsCsvdata::LEVEL_NO_VALUES.include?(level_no)
              invalid_csv_array[i][error_row_index] = level_no_error_message
              has_invalid = true
            end

            group_csv_hash_rows[i] = csv_hash_row
            # 階層レベル2のグループ
            if System::UsersGroupsCsvdata.level_no_2?(level_no)
              level_no_2_group_csv_hash_rows[i] = csv_hash_row
            # 階層レベル3のグループ
            else
              level_no_3_group_csv_hash_rows[i] = csv_hash_row
            end

          # 種別: ユーザー
          when System::UsersGroupsCsvdata.user_data_type
            user_csv_hash_rows[i] = csv_hash_row
          # その他(Error)
          else
            invalid_csv_array[i][error_row_index] = data_type_error_message
            has_invalid = true
          end
        end
      end

      ActiveRecord::Base.transaction do

        # グループ情報登録
        level_no_2_group_csv_hash_rows.each_with_index do |group_csv_hash_row, i|
          next if group_csv_hash_row.blank?

          group = System::UsersGroupsCsvdata.parse_csv(group_csv_hash_row)
          if group.invalid?
            invalid_csv_array[i][error_row_index] = group.error_full_messages
            has_invalid = true
          else
            group.save!
          end
        end

        level_no_3_group_csv_hash_rows.each_with_index do |group_csv_hash_row, i|
          next if group_csv_hash_row.blank?

          group = System::UsersGroupsCsvdata.parse_csv(group_csv_hash_row)
          if group.invalid?
            invalid_csv_array[i][error_row_index] = group.error_full_messages
            has_invalid = true
          else
            group.save!
          end
        end

        # ユーザー情報登録
        user_csv_hash_rows.each_with_index do |user_csv_hash_row, i|
          next if user_csv_hash_row.blank?

          user = System::UsersGroupsCsvdata.parse_csv(user_csv_hash_row)
          if user.invalid?
            invalid_csv_array[i][error_row_index] = user.error_full_messages
            has_invalid = true
          else
            user.save!
            # 同一codeのユーザーが存在する場合は、そのユーザー情報(最初にCSVで読み込まれて保存されたものを優先)で上書きする
            if user.origin_user.present?
              origin_user_profile = user.origin_user.user_profile
              if origin_user_profile.present?
                System::UsersGroupsCsvdataProfile.create!(
                  user_id: user.id, user_code: user.code,
                  add_column1: origin_user_profile.add_column1,
                  add_column2: origin_user_profile.add_column2,
                  add_column3: origin_user_profile.add_column3,
                  add_column4: origin_user_profile.add_column4,
                  add_column5: origin_user_profile.add_column5)
              end
            # 同一codeのユーザーが存在しない場合
            else
              # なにも入力されていなければプロフィールレコードを作成しない
              if user_csv_hash_row[:add_column1].present? || user_csv_hash_row[:add_column2].present? ||
                user_csv_hash_row[:add_column3].present? || user_csv_hash_row[:add_column4].present? ||
                user_csv_hash_row[:add_column5].present?

                System::UsersGroupsCsvdataProfile.create!(
                  user_id: user.id, user_code: user.code,
                  add_column1: user_csv_hash_row[:add_column1],
                  add_column2: user_csv_hash_row[:add_column2],
                  add_column3: user_csv_hash_row[:add_column3],
                  add_column4: user_csv_hash_row[:add_column4],
                  add_column5: user_csv_hash_row[:add_column5])
              end
            end

          end
        end

        raise "CSV情報に不備があります。" if has_invalid
      end

    rescue => e
      # 仮データを削除
      System::UsersGroupsCsvdata.delete_all
      has_invalid = true

      # 本番のログでも出力する
      Rails.logger.error "[ERROR] import_csv Invalid Error"
      Rails.logger.error e.inspect
    ensure
      # 検証結果: has_invalid: trueの場合は検証失敗
      return {
        invalid: has_invalid,
        invalid_csv_array: invalid_csv_array
      }
    end
  end

  # === CSV情報からModelのインスタンスを返すメソッド
  #
  # ==== 引数
  #  * csv_hash_row: CSV情報をHash化したもの
  # ==== 戻り値
  #  System::UsersGroupsCsvdata
  def self.parse_csv(csv_hash_row)
    csv_hash_row = csv_hash_row.dup

    # ユーザープロフィール項目
    add_column1 = csv_hash_row.delete(:add_column1)
    add_column2 = csv_hash_row.delete(:add_column2)
    add_column3 = csv_hash_row.delete(:add_column3)
    add_column4 = csv_hash_row.delete(:add_column4)
    add_column5 = csv_hash_row.delete(:add_column5)

    # 所属グループの親グループID
    parent_of_parent_code = csv_hash_row.delete(:parent_of_parent_code)

    # 状態
    state = csv_hash_row[:state]
    state_names = System::UsersGroup.state_names
    if state_names.include?(state)
      state = System::UsersGroup.state_values[state_names.index(state)]
    else
      state = nil
    end

    # LDAP同期
    ldap = csv_hash_row[:ldap]
    ldap_names = System::UsersGroup.ldap_names
    if ldap_names.include?(ldap)
      ldap = System::UsersGroup.ldap_values[ldap_names.index(ldap)]
    else
      ldap = nil
    end

    csv_hash_row.store(:state, state)
    csv_hash_row.store(:ldap, ldap)

    parsed_csv_data = System::UsersGroupsCsvdata.new(csv_hash_row)

    # 種別がグループの場合
    if parsed_csv_data.data_type_group?
      # 組織・任意
      category = csv_hash_row[:category]
      category_names = System::Group.category_names
      if category_names.include?(category)
        category = System::Group.category_values[category_names.index(category)]
      else
        category = nil
      end

      # 所属グループID
      parent_group = System::UsersGroupsCsvdata.extract_group.where(
        level_no: parsed_csv_data.level_no - 1, code: parsed_csv_data.parent_code).first
      parent_id = nil
      parent_id = parent_group.id if parent_group.present?

      parsed_csv_data.parent_id = parent_id
      parsed_csv_data.category = category
    end

    # 種別がユーザーの場合
    if parsed_csv_data.data_type_user?
      # 本務・兼務
      job_order = csv_hash_row[:job_order]
      job_order_names = System::UsersGroup.job_order_names
      if job_order_names.include?(job_order)
        job_order = System::UsersGroup.job_order_values[job_order_names.index(job_order)]
      else
        job_order = nil
      end

      # 所属グループID: 所属グループの親グループIDが空の場合はスキップさせる
      parent_group = nil
      if parent_of_parent_code.present?
        # 所属グループIDは所属グループの親グループで絞込んでから所属グループIDで絞り込む
        parent_of_parent_group = System::UsersGroupsCsvdata.extract_group.where(
          code: parent_of_parent_code).where("level_no < 3").first
        # 所属グループの親グループが見つかれば所属グループIDで絞り込む
        parent_group = parent_of_parent_group.groups.where(
          code: parsed_csv_data.parent_code).first if parent_of_parent_group.present?
      end
      parent_id = nil
      parent_id = parent_group.id if parent_group.present?

      parsed_csv_data.parent_id = parent_id
      parsed_csv_data.job_order = job_order

      # 同一codeのユーザーが存在する場合は、そのユーザー情報(最初にCSVで読み込まれて保存されたものを優先)で上書きする
      exist_user = System::UsersGroupsCsvdata.unscoped.extract_user.where(
        code: parsed_csv_data.code).order(:id).first
      if exist_user.present?
        parsed_csv_data.state = exist_user.state
        parsed_csv_data.ldap = exist_user.ldap
        parsed_csv_data.name = exist_user.name
        parsed_csv_data.name_en = exist_user.name_en
        parsed_csv_data.email = exist_user.email
        parsed_csv_data.sort_no = exist_user.sort_no
        parsed_csv_data.password = exist_user.password
        parsed_csv_data.official_position = exist_user.official_position
        parsed_csv_data.assigned_job = exist_user.assigned_job

        parsed_csv_data.origin_user = exist_user
      end
    end

    return parsed_csv_data
  end

  # === グループ情報のマージ： 既存のレコードがあれば上書きする、既存のレコードがなければ新規作成する
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def update_or_create_by_system_group!
    # 階層レベル2からグループをマージしているので必ずparent_groupは存在する
    exist_parent_group = System::Group.where(level_no: self.level_no - 1, code: self.parent_code).first

    update_or_create_attributes = {
      state: self.state, level_no: self.level_no, parent_id: exist_parent_group.id,
      code: self.code, category: self.category, ldap: self.ldap, ldap_version: nil,
      name: self.name, name_en: self.name_en, email: self.email, sort_no: self.sort_no,
      start_at: self.start_at, end_at: self.end_at, version_id: 0
    }

    exist_group = exist_parent_group.children.where(
      code: self.code, level_no: self.level_no).first

    if exist_group
      exist_group.update_attributes!(update_or_create_attributes)
    else
      System::Group.create!(update_or_create_attributes)
    end
  end

  # === ユーザー情報のマージ： 既存のレコードがあれば上書きする、既存のレコードがなければ新規作成する
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def update_or_create_by_system_user!
    # 同一codeのユーザーが存在する場合、CSV仮登録で同じ値にしているため値は変化しない
    update_or_create_user_attributes = {
      state: self.state, code: self.code, ldap: self.ldap, ldap_version: nil,
      name: self.name, name_en: self.name_en, email: self.email, sort_no: self.sort_no,
      password: self.password, official_position: self.official_position, assigned_job: self.assigned_job
    }

    # ユーザー情報
    exist_user = System::User.where(code: self.code).first
    if exist_user
      # 既に更新済の場合は値が変化しないため更新されない
      exist_user.update_attributes!(update_or_create_user_attributes)
      target_user = exist_user
    else
      target_user = System::User.create!(update_or_create_user_attributes)
    end
    # ユーザープロフィール情報
    update_or_create_by_system_user_profile!(target_user)
    # ユーザー・グループ情報
    update_or_create_by_system_user_group!(target_user)
  end

  # === ユーザープロフィール情報のマージ： 既存のレコードがあれば上書きする、既存のレコードがなければ新規作成する
  #
  # ==== 引数
  #  * target_user: 本ユーザーレコード（仮データではない）
  # ==== 戻り値
  #  なし
  def update_or_create_by_system_user_profile!(target_user)
    # 仮データ登録時に何かしらプロフィール項目に入力があったもののみマージする
    if self.user_profile.present?
      update_or_create_user_profile_attributes = {
        user_id: target_user.id, user_code: target_user.code,
        add_column1: self.add_column1, add_column2: self.add_column2,
        add_column3: self.add_column3, add_column4: self.add_column4,
        add_column5: self.add_column5
      }

      if target_user.user_profile.present?
        # 既に更新済の場合は値が変化しないため更新されない
        target_user.user_profile.update_attributes!(update_or_create_user_profile_attributes)
      else
        System::UsersProfile.create!(update_or_create_user_profile_attributes)
      end
    end
  end

  # === ユーザー・グループ情報のマージ： 既存のレコードがあれば上書きする、既存のレコードがなければ新規作成する
  #
  # ==== 引数
  #  * target_user: 本ユーザーレコード（仮データではない）
  # ==== 戻り値
  #  なし
  def update_or_create_by_system_user_group!(target_user)
    target_parent_group = System::Group.without_level_no_3.where(code: self.parent.parent.code).first
    target_group = target_parent_group.children.where(code: self.parent_code).first

    # user_code, group_code は before_save の set_columns で更新される
    update_or_create_user_group_attributes = {
      user_id: target_user.id, group_id: target_group.id,
      start_at: self.start_at, end_at: self.end_at, job_order: self.job_order,
      # user_idのvalidation回避のオプション
      csv_import_mode: true
    }

    # ユーザー情報
    exist_user_group = System::UsersGroup.where(user_id: target_user.id, group_id: target_group.id).first
    if exist_user_group
      exist_user_group.update_attributes!(update_or_create_user_group_attributes)
    else
      System::UsersGroup.create!(update_or_create_user_group_attributes)
    end
  end

  # === CSVに使用する項目一覧
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  Hash
  def self.csv_header
    return {
      state: self.human_attribute_name(:state),
      data_type: self.human_attribute_name(:data_type),
      level_no: self.human_attribute_name(:level_no),
      parent_of_parent_code: self.human_attribute_name(:parent_of_parent_code),
      parent_code: self.human_attribute_name(:parent_code),
      code: self.human_attribute_name(:code),
      category: self.human_attribute_name(:category),
      ldap: self.human_attribute_name(:ldap),
      job_order: self.human_attribute_name(:job_order),
      name: self.human_attribute_name(:name),
      name_en: self.human_attribute_name(:name_en),
      password: self.human_attribute_name(:password),
      email: self.human_attribute_name(:email),
      sort_no: self.human_attribute_name(:sort_no),
      official_position: self.human_attribute_name(:official_position),
      assigned_job: self.human_attribute_name(:assigned_job),
      start_at: self.human_attribute_name(:start_at),
      end_at: self.human_attribute_name(:end_at),
      add_column1: self.human_attribute_name(:add_column1),
      add_column2: self.human_attribute_name(:add_column2),
      add_column3: self.human_attribute_name(:add_column3),
      add_column4: self.human_attribute_name(:add_column4),
      add_column5: self.human_attribute_name(:add_column5)
    }
  end

  # === 階層レベル1のグループを作成するメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def self.create_root_group
    root_group = System::Group.extract_root.first

    dummy_root_group = System::UsersGroupsCsvdata.new(
      data_type: System::UsersGroupsCsvdata.group_data_type,
      code: root_group.code, name: root_group.name, level_no: root_group.level_no,
      parent_id: root_group.parent_id, parent_code: "dummy_root_parent_code",
      ldap: root_group.ldap, email: root_group.email, sort_no: root_group.sort_no,
      start_at: root_group.start_at, category: root_group.category,
      state: root_group.state)
    # 検証なしで保存
    dummy_root_group.save(validate: false)
  end

  # === 種別で使用されている表示名を返すメソッド
  #
  # ==== 引数
  #  * data_type: 種別(group|user)
  # ==== 戻り値
  #  文字列
  def self.data_type_show(data_type)
    return I18n.t("rumi.config_settings.base.user_and_group.csv.data_type.#{data_type}")
  end

  def self.truncate_table
    connect = self.connection()
    truncate_query = "TRUNCATE TABLE `#{self.table_name}` ;"
    connect.execute(truncate_query)
  end

  def self.set_autoincrement_number
    # auto_incrementを設定。truncate_tableの後に実行。
    id = self.maximum(:id)
    id = nz(id, 0) + 1
    connect = self.connection()
    truncate_query = "ALTER TABLE `#{self.table_name}` AUTO_INCREMENT=#{id}"
    connect.execute(truncate_query)
  end

  # 以下、プライベートメソッド
  private

  # === 追加項目の値を返すメソッド
  #
  # ==== 引数
  #  * column_number: 追加項目の何番目か
  # ==== 戻り値
  #  追加項目
  def add_column(column_number)
    if data_type_user? && user_profile.present?
      return user_profile.send("add_column#{column_number}".to_sym)
    else
      return ""
    end
  end

end